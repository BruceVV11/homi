"use strict";

const {createHash} = require("node:crypto");
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {onMessagePublished} = require("firebase-functions/v2/pubsub");
const {
  onDocumentWritten,
  onDocumentDeleted,
} = require("firebase-functions/v2/firestore");
const logger = require("firebase-functions/logger");
const {getFirestore, FieldValue, Timestamp} = require("firebase-admin/firestore");
const {GoogleAuth} = require("google-auth-library");
const {
  DUO_REASSIGNMENT_COOLDOWN_DAYS,
  normalizePlayState,
  grantsPaidAccess,
  entitlementCapabilities,
  configuredCatalog,
  productFor,
} = require("./billing_policy");

const db = getFirestore();
const PACKAGE_NAME = "za.co.theconceptlab.homi";
const PLAY_SCOPE = "https://www.googleapis.com/auth/androidpublisher";
const RTDN_TOPIC = "homi-google-play-rtdn";
const MAX_TOKEN_LENGTH = 4096;
const auth = new GoogleAuth({scopes: [PLAY_SCOPE]});

function sha256(value) {
  return createHash("sha256").update(String(value), "utf8").digest("hex");
}

function obfuscatedAccountId(uid) {
  return sha256(`homi:${uid}`);
}

function cleanToken(value) {
  const token = String(value || "").trim();
  if (!token || token.length > MAX_TOKEN_LENGTH) {
    throw new HttpsError("invalid-argument", "Google Play did not provide a valid purchase token.");
  }
  return token;
}

function requireAuth(request) {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign in to manage Homi+.");
  }
  const provider = request.auth.token && request.auth.token.firebase &&
    request.auth.token.firebase.sign_in_provider;
  if (provider === "password" && request.auth.token.email_verified !== true) {
    throw new HttpsError("failed-precondition", "Verify your email before purchasing Homi+.");
  }
  return request.auth;
}

function catalogOrThrow() {
  const catalog = configuredCatalog(process.env);
  if (!catalog.configured) {
    throw new HttpsError(
        "failed-precondition",
        "Homi+ is not connected to the Google Play subscription catalog yet.",
    );
  }
  return catalog;
}

async function playRequest(path, {method = "GET", body} = {}) {
  const client = await auth.getClient();
  const url = `https://androidpublisher.googleapis.com${path}`;
  const authHeaders = await client.getRequestHeaders(url);
  const response = await fetch(url, {
    method,
    headers: {
      ...authHeaders,
      Accept: "application/json",
      ...(body === undefined ? {} : {"Content-Type": "application/json"}),
    },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  if (!response.ok) {
    const text = await response.text();
    const error = new Error(`Google Play API ${response.status}`);
    error.status = response.status;
    error.responseBody = text.slice(0, 500);
    throw error;
  }
  if (response.status === 204) return {};
  const text = await response.text();
  return text ? JSON.parse(text) : {};
}

async function fetchSubscription(purchaseToken) {
  return playRequest(
      `/androidpublisher/v3/applications/${encodeURIComponent(PACKAGE_NAME)}` +
      `/purchases/subscriptionsv2/tokens/${encodeURIComponent(purchaseToken)}`,
  );
}

async function acknowledgeSubscription(productId, purchaseToken) {
  await playRequest(
      `/androidpublisher/v3/applications/${encodeURIComponent(PACKAGE_NAME)}` +
      `/purchases/subscriptions/${encodeURIComponent(productId)}` +
      `/tokens/${encodeURIComponent(purchaseToken)}:acknowledge`,
      {method: "POST", body: {}},
  );
}

function expiryFrom(lineItems) {
  let latest = null;
  for (const item of lineItems || []) {
    if (!item || !item.expiryTime) continue;
    const parsed = Date.parse(item.expiryTime);
    if (!Number.isFinite(parsed)) continue;
    if (latest === null || parsed > latest) latest = parsed;
  }
  return latest === null ? null : Timestamp.fromMillis(latest);
}

function purchaseIdentity(playPurchase, expectedProductId = null) {
  const catalog = catalogOrThrow();
  const lineItems = Array.isArray(playPurchase.lineItems) ? playPurchase.lineItems : [];
  const candidates = lineItems.filter((item) => {
    if (!item || typeof item.productId !== "string") return false;
    if (expectedProductId && item.productId !== expectedProductId) return false;
    const basePlanId = item.offerDetails && item.offerDetails.basePlanId;
    return Boolean(productFor(catalog, item.productId, basePlanId));
  });
  if (candidates.length === 0) {
    throw new HttpsError("failed-precondition", "That Google Play subscription is not a Homi+ plan.");
  }
  const item = candidates[0];
  const basePlanId = item.offerDetails.basePlanId;
  const product = productFor(catalog, item.productId, basePlanId);
  return {
    plan: product.plan,
    productId: item.productId,
    basePlanId,
    validUntil: expiryFrom(lineItems),
  };
}

async function resolveUidFromPlay(playPurchase, purchaseTokenHash) {
  const external = playPurchase.externalAccountIdentifiers || {};
  const accountId = String(external.obfuscatedExternalAccountId || "").trim();
  if (!accountId) return null;
  const link = await db.collection("billingAccountLinks").doc(accountId).get();
  if (!link.exists) return null;
  const uid = String(link.data().uid || "").trim();
  if (!uid) return null;
  const account = await db.collection("billingAccounts").doc(uid).get();
  if (!account.exists) return null;
  const activeHash = String(account.data().activePurchaseTokenHash || "");
  if (activeHash && activeHash !== purchaseTokenHash) return null;
  return uid;
}

async function canonicalHouseholdFor(uid) {
  const membership = await db.collection("householdMemberships").doc(uid).get();
  if (!membership.exists) return null;
  const householdId = String(membership.data().householdId || "").trim();
  if (!householdId) return null;
  const household = await db.collection("households").doc(householdId).get();
  if (!household.exists) return null;
  const memberUids = Array.isArray(household.data().memberUids) ?
    household.data().memberUids.filter((value) => typeof value === "string") : [];
  if (!memberUids.includes(uid)) return null;
  return {
    householdId,
    ownerUid: String(household.data().ownerUid || ""),
    memberUids,
  };
}

async function acceptedConnection(firstUid, secondUid) {
  const ids = [firstUid, secondUid].sort();
  const snapshot = await db.collection("connections").doc(`${ids[0]}_${ids[1]}`).get();
  if (!snapshot.exists) return false;
  const data = snapshot.data();
  return data.status === "accepted" && data.aUid === ids[0] && data.bUid === ids[1];
}

function entitlementDocument({
  plan,
  state,
  purchaserUid,
  purchaseTokenHash,
  seatRole,
  householdId = null,
  duoSeatAssigneeUid = null,
  validUntil = null,
}) {
  return {
    plan,
    state,
    purchaserUid,
    sourcePurchaseTokenHash: purchaseTokenHash,
    seatRole,
    householdId,
    duoSeatAssigneeUid,
    validUntil,
    ...entitlementCapabilities(plan, state),
    updatedAt: FieldValue.serverTimestamp(),
  };
}

async function currentPurchaseForPurchaser(uid) {
  const account = await db.collection("billingAccounts").doc(uid).get();
  if (!account.exists) return null;
  const tokenHash = String(account.data().activePurchaseTokenHash || "").trim();
  if (!tokenHash) return null;
  const purchase = await db.collection("billingPurchases").doc(tokenHash).get();
  if (!purchase.exists) return null;
  if (purchase.data().purchaserUid !== uid || purchase.data().supersededByTokenHash) return null;
  return {ref: purchase.ref, tokenHash, data: purchase.data()};
}

async function entitlementRecipientsForPurchase(purchase) {
  const recipients = new Map();
  const data = purchase.data;
  const purchaserUid = String(data.purchaserUid || "").trim();
  if (!purchaserUid) return recipients;
  recipients.set(purchaserUid, "purchaser");
  if (!grantsPaidAccess(data.state)) return recipients;

  if (data.plan === "duo") {
    const account = await db.collection("billingAccounts").doc(purchaserUid).get();
    const secondaryUid = account.exists ?
      String(account.data().duoSecondaryUid || "").trim() : "";
    if (secondaryUid && await acceptedConnection(purchaserUid, secondaryUid)) {
      recipients.set(secondaryUid, "duo_secondary");
    }
  }

  if (data.plan === "household") {
    let householdId = String(data.householdId || "").trim();
    let household = null;
    if (householdId) {
      const snapshot = await db.collection("households").doc(householdId).get();
      if (snapshot.exists) {
        household = {
          householdId,
          memberUids: Array.isArray(snapshot.data().memberUids) ?
            snapshot.data().memberUids.filter((value) => typeof value === "string") : [],
        };
      }
    }
    if (!household) {
      household = await canonicalHouseholdFor(purchaserUid);
      if (household) {
        householdId = household.householdId;
        await purchase.ref.set({householdId}, {merge: true});
      }
    }
    if (household) {
      for (const memberUid of household.memberUids.slice(0, 4)) {
        recipients.set(memberUid, memberUid === purchaserUid ? "purchaser" : "household_member");
      }
    }
  }
  return recipients;
}

async function reconcilePurchaseEntitlements(purchase) {
  const data = purchase.data;
  const purchaseTokenHash = purchase.tokenHash;
  const purchaserUid = String(data.purchaserUid || "").trim();
  if (!purchaserUid) return;

  const recipients = await entitlementRecipientsForPurchase(purchase);
  const existing = await db.collection("entitlements")
      .where("sourcePurchaseTokenHash", "==", purchaseTokenHash).get();
  const batch = db.batch();
  const desired = new Set(recipients.keys());

  for (const document of existing.docs) {
    if (!desired.has(document.id)) batch.delete(document.ref);
  }

  const accountSnapshot = await db.collection("billingAccounts").doc(purchaserUid).get();
  const duoSeatAssigneeUid = accountSnapshot.exists ?
    String(accountSnapshot.data().duoSecondaryUid || "").trim() || null : null;
  const householdId = String(data.householdId || "").trim() || null;
  for (const [uid, seatRole] of recipients.entries()) {
    batch.set(
        db.collection("entitlements").doc(uid),
        entitlementDocument({
          plan: data.plan,
          state: data.state,
          purchaserUid,
          purchaseTokenHash,
          seatRole,
          householdId,
          duoSeatAssigneeUid,
          validUntil: data.validUntil || null,
        }),
        {merge: false},
    );
  }
  await batch.commit();
}

async function persistVerifiedPurchase({
  purchaserUid,
  purchaseToken,
  expectedProductId = null,
  playPurchase,
  allowAccountLinkCreation,
}) {
  const purchaseTokenHash = sha256(purchaseToken);
  const identity = purchaseIdentity(playPurchase, expectedProductId);
  const state = normalizePlayState(playPurchase.subscriptionState);
  const expectedAccountId = obfuscatedAccountId(purchaserUid);
  const external = playPurchase.externalAccountIdentifiers || {};
  const actualAccountId = String(external.obfuscatedExternalAccountId || "").trim();
  if (!actualAccountId || actualAccountId !== expectedAccountId) {
    throw new HttpsError(
        "permission-denied",
        "This Google Play subscription belongs to a different Homi account.",
    );
  }

  const purchaseRef = db.collection("billingPurchases").doc(purchaseTokenHash);
  const accountRef = db.collection("billingAccounts").doc(purchaserUid);
  const linkRef = db.collection("billingAccountLinks").doc(expectedAccountId);
  let previousTokenHash = null;

  await db.runTransaction(async (transaction) => {
    const [existingPurchase, accountSnapshot, linkSnapshot] = await Promise.all([
      transaction.get(purchaseRef),
      transaction.get(accountRef),
      transaction.get(linkRef),
    ]);
    if (existingPurchase.exists) {
      const previousPurchaser = String(existingPurchase.data().purchaserUid || "");
      if (previousPurchaser && previousPurchaser !== purchaserUid) {
        throw new HttpsError("permission-denied", "This purchase has already been claimed by another Homi account.");
      }
    }
    if (linkSnapshot.exists && linkSnapshot.data().uid !== purchaserUid) {
      throw new HttpsError("permission-denied", "This Google Play account link is already in use.");
    }
    if (!linkSnapshot.exists && !allowAccountLinkCreation) {
      throw new HttpsError("failed-precondition", "Homi could not resolve the account for this subscription update.");
    }

    previousTokenHash = accountSnapshot.exists ?
      String(accountSnapshot.data().activePurchaseTokenHash || "").trim() || null : null;
    transaction.set(linkRef, {
      uid: purchaserUid,
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: true});
    transaction.set(accountRef, {
      activePurchaseTokenHash: purchaseTokenHash,
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: true});
    transaction.set(purchaseRef, {
      purchaseToken,
      purchaseTokenHash,
      purchaserUid,
      packageName: PACKAGE_NAME,
      productId: identity.productId,
      basePlanId: identity.basePlanId,
      plan: identity.plan,
      state,
      validUntil: identity.validUntil,
      acknowledgementState: playPurchase.acknowledgementState || null,
      latestOrderId: playPurchase.latestOrderId || null,
      updatedAt: FieldValue.serverTimestamp(),
      verifiedAt: FieldValue.serverTimestamp(),
      supersededByTokenHash: FieldValue.delete(),
    }, {merge: true});
    if (previousTokenHash && previousTokenHash !== purchaseTokenHash) {
      transaction.set(
          db.collection("billingPurchases").doc(previousTokenHash),
          {
            supersededByTokenHash: purchaseTokenHash,
            updatedAt: FieldValue.serverTimestamp(),
          },
          {merge: true},
      );
    }
  });

  if (
    grantsPaidAccess(state) &&
    playPurchase.acknowledgementState === "ACKNOWLEDGEMENT_STATE_PENDING"
  ) {
    await acknowledgeSubscription(identity.productId, purchaseToken);
    await purchaseRef.set({
      acknowledgementState: "ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED",
      acknowledgedAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: true});
  }

  const household = identity.plan === "household" ?
    await canonicalHouseholdFor(purchaserUid) : null;
  if (household) {
    await purchaseRef.set({householdId: household.householdId}, {merge: true});
  }
  const finalSnapshot = await purchaseRef.get();
  await reconcilePurchaseEntitlements({
    ref: purchaseRef,
    tokenHash: purchaseTokenHash,
    data: finalSnapshot.data(),
  });

  if (previousTokenHash && previousTokenHash !== purchaseTokenHash) {
    const oldEntitlements = await db.collection("entitlements")
        .where("sourcePurchaseTokenHash", "==", previousTokenHash).get();
    const batch = db.batch();
    oldEntitlements.docs.forEach((document) => batch.delete(document.ref));
    await batch.commit();
  }

  return {
    purchaseTokenHash,
    plan: identity.plan,
    state,
    productId: identity.productId,
    basePlanId: identity.basePlanId,
  };
}

async function refreshStoredPurchase(purchaseToken, purchaserUid = null) {
  const purchaseTokenHash = sha256(purchaseToken);
  const playPurchase = await fetchSubscription(purchaseToken);
  let resolvedUid = purchaserUid;
  if (!resolvedUid) {
    const stored = await db.collection("billingPurchases").doc(purchaseTokenHash).get();
    if (stored.exists) resolvedUid = String(stored.data().purchaserUid || "").trim() || null;
  }
  if (!resolvedUid) {
    resolvedUid = await resolveUidFromPlay(playPurchase, purchaseTokenHash);
  }
  if (!resolvedUid) {
    logger.warn("Homi billing RTDN could not resolve a Homi account", {purchaseTokenHash});
    return null;
  }

  const account = await db.collection("billingAccounts").doc(resolvedUid).get();
  if (account.exists) {
    const activeHash = String(account.data().activePurchaseTokenHash || "").trim();
    if (activeHash && activeHash !== purchaseTokenHash) {
      const identity = purchaseIdentity(playPurchase);
      await db.collection("billingPurchases").doc(purchaseTokenHash).set({
        state: normalizePlayState(playPurchase.subscriptionState),
        validUntil: identity.validUntil,
        acknowledgementState: playPurchase.acknowledgementState || null,
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      return {ignoredSuperseded: true, purchaserUid: resolvedUid};
    }
  }

  return persistVerifiedPurchase({
    purchaserUid: resolvedUid,
    purchaseToken,
    playPurchase,
    allowAccountLinkCreation: false,
  });
}

exports.verifyGooglePlaySubscription = onCall(
    {enforceAppCheck: true, maxInstances: 3, timeoutSeconds: 60},
    async (request) => {
      const user = requireAuth(request);
      catalogOrThrow();
      const purchaseToken = cleanToken(request.data && request.data.purchaseToken);
      const expectedProductId = String(request.data && request.data.productId || "").trim();
      const catalog = configuredCatalog(process.env);
      if (!catalog.products.some((item) => item.productId === expectedProductId)) {
        throw new HttpsError("invalid-argument", "Choose a configured Homi+ subscription.");
      }

      let playPurchase;
      try {
        playPurchase = await fetchSubscription(purchaseToken);
      } catch (error) {
        logger.error("Google Play verification failed", {
          uid: user.uid,
          status: error && error.status,
        });
        throw new HttpsError(
            error && error.status === 403 ? "failed-precondition" : "unavailable",
            error && error.status === 403 ?
              "Homi's Google Play verification access is not configured yet." :
              "Homi could not verify this Google Play purchase right now.",
        );
      }

      const verified = await persistVerifiedPurchase({
        purchaserUid: user.uid,
        purchaseToken,
        expectedProductId,
        playPurchase,
        allowAccountLinkCreation: true,
      });
      return {verified: true, plan: verified.plan, state: verified.state};
    },
);

exports.setHomiPlusDuoSeat = onCall(
    {enforceAppCheck: true, maxInstances: 3, timeoutSeconds: 30},
    async (request) => {
      const user = requireAuth(request);
      const purchase = await currentPurchaseForPurchaser(user.uid);
      if (!purchase || purchase.data.plan !== "duo" || !grantsPaidAccess(purchase.data.state)) {
        throw new HttpsError("failed-precondition", "An active Homi+ Duo subscription is required.");
      }

      const requestedUid = String(request.data && request.data.secondaryUid || "").trim();
      if (requestedUid === user.uid) {
        throw new HttpsError("invalid-argument", "Your own account already uses the first Duo seat.");
      }
      if (requestedUid && !await acceptedConnection(user.uid, requestedUid)) {
        throw new HttpsError("failed-precondition", "Connect with this person in Homi before assigning the second Duo seat.");
      }

      const accountRef = db.collection("billingAccounts").doc(user.uid);
      const account = await accountRef.get();
      const currentUid = account.exists ? String(account.data().duoSecondaryUid || "").trim() : "";
      const canReassignAt = account.exists && account.data().duoCanReassignAt &&
        typeof account.data().duoCanReassignAt.toMillis === "function" ?
        account.data().duoCanReassignAt.toMillis() : 0;
      if (currentUid && currentUid !== requestedUid && canReassignAt > Date.now()) {
        throw new HttpsError(
            "failed-precondition",
            "The second Duo seat cannot be reassigned yet.",
        );
      }

      const nextReassignAt = requestedUid ? Timestamp.fromMillis(
          Date.now() + DUO_REASSIGNMENT_COOLDOWN_DAYS * 24 * 60 * 60 * 1000,
      ) : null;
      await accountRef.set({
        duoSecondaryUid: requestedUid || FieldValue.delete(),
        duoCanReassignAt: requestedUid ? nextReassignAt : FieldValue.delete(),
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      await reconcilePurchaseEntitlements(purchase);
      return {
        assigned: Boolean(requestedUid),
        canReassignAt: nextReassignAt ? nextReassignAt.toDate().toISOString() : null,
      };
    },
);

exports.onGooglePlayBillingNotification = onMessagePublished(
    {
      topic: RTDN_TOPIC,
      region: "africa-south1",
      maxInstances: 3,
      timeoutSeconds: 60,
    },
    async (event) => {
      let payload;
      try {
        payload = event.data.message.json;
      } catch (error) {
        logger.error("Homi Google Play RTDN was not JSON", {messageId: event.data.message.messageId});
        return;
      }
      if (!payload || payload.packageName !== PACKAGE_NAME) return;
      const notification = payload.subscriptionNotification;
      const purchaseToken = notification && String(notification.purchaseToken || "").trim();
      if (!purchaseToken) return;
      try {
        await refreshStoredPurchase(purchaseToken);
      } catch (error) {
        logger.error("Homi Google Play RTDN refresh failed", {
          purchaseTokenHash: sha256(purchaseToken),
          status: error && error.status,
          message: error && error.message,
        });
        throw error;
      }
    },
);

exports.onHomiPlusHouseholdChanged = onDocumentWritten(
    "households/{householdId}",
    async (event) => {
      const householdId = event.params.householdId;
      const after = event.data && event.data.after && event.data.after.exists ?
        event.data.after.data() : null;
      const before = event.data && event.data.before && event.data.before.exists ?
        event.data.before.data() : null;
      const purchaserCandidates = new Set();
      if (after && after.ownerUid) purchaserCandidates.add(after.ownerUid);
      if (before && before.ownerUid) purchaserCandidates.add(before.ownerUid);

      const attached = await db.collection("billingPurchases")
          .where("householdId", "==", householdId).get();
      for (const document of attached.docs) {
        const data = document.data();
        if (data.plan !== "household" || data.supersededByTokenHash) continue;
        if (!after) {
          await document.ref.set({
            householdId: FieldValue.delete(),
            updatedAt: FieldValue.serverTimestamp(),
          }, {merge: true});
        }
        const refreshed = await document.ref.get();
        await reconcilePurchaseEntitlements({
          ref: document.ref,
          tokenHash: document.id,
          data: refreshed.data(),
        });
      }

      if (after) {
        for (const uid of purchaserCandidates) {
          const purchase = await currentPurchaseForPurchaser(uid);
          if (!purchase || purchase.data.plan !== "household" || !grantsPaidAccess(purchase.data.state)) {
            continue;
          }
          if (!purchase.data.householdId) {
            await purchase.ref.set({
              householdId,
              updatedAt: FieldValue.serverTimestamp(),
            }, {merge: true});
            const refreshed = await purchase.ref.get();
            await reconcilePurchaseEntitlements({
              ref: purchase.ref,
              tokenHash: purchase.tokenHash,
              data: refreshed.data(),
            });
          }
        }
      }
    },
);

exports.onHomiPlusConnectionDeleted = onDocumentDeleted(
    "connections/{connectionId}",
    async (event) => {
      const data = event.data && event.data.data();
      if (!data) return;
      const uids = [data.aUid, data.bUid].filter((value) => typeof value === "string" && value);
      for (const secondaryUid of uids) {
        const assignments = await db.collection("billingAccounts")
            .where("duoSecondaryUid", "==", secondaryUid).get();
        for (const account of assignments.docs) {
          const purchaserUid = account.id;
          if (!uids.includes(purchaserUid)) continue;
          await account.ref.set({
            duoSecondaryUid: FieldValue.delete(),
            duoCanReassignAt: FieldValue.delete(),
            updatedAt: FieldValue.serverTimestamp(),
          }, {merge: true});
          const purchase = await currentPurchaseForPurchaser(purchaserUid);
          if (purchase && purchase.data.plan === "duo") {
            await reconcilePurchaseEntitlements(purchase);
          }
        }
      }
    },
);

exports.onHomiPlusUserDeleted = onDocumentDeleted(
    "users/{uid}",
    async (event) => {
      const uid = event.params.uid;
      const accountId = obfuscatedAccountId(uid);
      const accountRef = db.collection("billingAccounts").doc(uid);
      const account = await accountRef.get();
      const activeTokenHash = account.exists ?
        String(account.data().activePurchaseTokenHash || "").trim() : "";
      if (activeTokenHash) {
        await db.collection("billingPurchases").doc(activeTokenHash).set({
          purchaserUid: FieldValue.delete(),
          accountDeletedAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        }, {merge: true});
      }

      const purchaserEntitlements = await db.collection("entitlements")
          .where("purchaserUid", "==", uid).get();
      const secondaryAssignments = await db.collection("billingAccounts")
          .where("duoSecondaryUid", "==", uid).get();
      const batch = db.batch();
      purchaserEntitlements.docs.forEach((document) => batch.delete(document.ref));
      batch.delete(db.collection("entitlements").doc(uid));
      batch.delete(db.collection("billingAccountLinks").doc(accountId));
      batch.delete(accountRef);
      secondaryAssignments.docs.forEach((document) => {
        batch.set(document.ref, {
          duoSecondaryUid: FieldValue.delete(),
          duoCanReassignAt: FieldValue.delete(),
          updatedAt: FieldValue.serverTimestamp(),
        }, {merge: true});
      });
      await batch.commit();

      for (const document of secondaryAssignments.docs) {
        const purchase = await currentPurchaseForPurchaser(document.id);
        if (purchase && purchase.data.plan === "duo") {
          await reconcilePurchaseEntitlements(purchase);
        }
      }
    },
);
