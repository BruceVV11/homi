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
  effectivePlayState,
  grantsPaidAccess,
  entitlementCapabilities,
  projectEntitlementSources,
  canAdoptCanonicalPurchase,
  configuredCatalog,
  productFor,
} = require("./billing_policy");

const db = getFirestore();
const PACKAGE_NAME = "za.co.theconceptlab.homi";
const PLAY_SCOPE = "https://www.googleapis.com/auth/androidpublisher";
const RTDN_TOPIC = "homi-google-play-rtdn";
const MAX_TOKEN_LENGTH = 4096;
const HOUR_MS = 60 * 60 * 1000;
const auth = new GoogleAuth({scopes: [PLAY_SCOPE]});

function sha256(value) {
  return createHash("sha256").update(String(value), "utf8").digest("hex");
}

function obfuscatedAccountId(uid) {
  return sha256(`homi:${uid}`);
}

function coverageDocId(purchaseTokenHash, uid) {
  return `${purchaseTokenHash}_${sha256(uid).slice(0, 24)}`;
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

async function requireBillingRateLimit(uid, scope, limit) {
  const ref = db.collection("serverRateLimits").doc(`${scope}_${uid}`);
  const now = Date.now();
  const allowed = await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(ref);
    const data = snapshot.exists ? snapshot.data() : {};
    const storedStart = Number(data.windowStartMs || 0);
    const expired = !storedStart || now - storedStart >= HOUR_MS;
    const count = expired ? 0 : Number(data.count || 0);
    if (count >= limit) return false;
    transaction.set(ref, {
      scope,
      actorUid: uid,
      windowStartMs: expired ? now : storedStart,
      count: count + 1,
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: true});
    return true;
  });
  if (!allowed) {
    throw new HttpsError("resource-exhausted", "Too many billing requests. Wait a while and try again.");
  }
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
  const headerObject = typeof authHeaders.entries === "function" ?
    Object.fromEntries(authHeaders.entries()) : authHeaders;
  const response = await fetch(url, {
    method,
    headers: {
      ...headerObject,
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

async function resolveUidFromPlay(playPurchase) {
  const external = playPurchase.externalAccountIdentifiers || {};
  const accountId = String(external.obfuscatedExternalAccountId || "").trim();
  if (!accountId) return null;
  const link = await db.collection("billingAccountLinks").doc(accountId).get();
  if (!link.exists) return null;
  const uid = String(link.data().uid || "").trim();
  if (!uid) return null;
  const account = await db.collection("billingAccounts").doc(uid).get();
  if (!account.exists) return null;
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

function coverageDocument({
  plan,
  state,
  purchaserUid,
  purchaseTokenHash,
  recipientUid,
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
    recipientUid,
    seatRole,
    householdId,
    duoSeatAssigneeUid,
    validUntil,
    ...entitlementCapabilities(plan, state),
    updatedAt: FieldValue.serverTimestamp(),
  };
}

async function recomputeEntitlement(uid) {
  const snapshot = await db.collection("billingCoverage")
      .where("recipientUid", "==", uid).get();
  const sources = snapshot.docs.map((document) => document.data());
  const projection = projectEntitlementSources(sources);
  const ref = db.collection("entitlements").doc(uid);
  if (!projection) {
    await ref.delete().catch((error) => {
      if (!error || error.code !== 5) throw error;
    });
    return;
  }
  await ref.set({
    ...projection,
    updatedAt: FieldValue.serverTimestamp(),
  }, {merge: false});
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
  const effectiveState = effectivePlayState(data.state, data.validUntil);
  if (!purchaserUid) {
    return {
      recipients,
      householdId: null,
      duoSeatAssigneeUid: null,
      effectiveState,
    };
  }

  recipients.set(purchaserUid, "purchaser");
  let householdId = null;
  let duoSeatAssigneeUid = null;
  if (!grantsPaidAccess(effectiveState)) {
    return {recipients, householdId, duoSeatAssigneeUid, effectiveState};
  }

  if (data.plan === "duo") {
    const account = await db.collection("billingAccounts").doc(purchaserUid).get();
    const secondaryUid = account.exists ?
      String(account.data().duoSecondaryUid || "").trim() : "";
    if (secondaryUid && await acceptedConnection(purchaserUid, secondaryUid)) {
      duoSeatAssigneeUid = secondaryUid;
      recipients.set(secondaryUid, "duo_secondary");
    }
  }

  if (data.plan === "household") {
    const household = await canonicalHouseholdFor(purchaserUid);
    if (household) {
      householdId = household.householdId;
      for (const memberUid of household.memberUids.slice(0, 4)) {
        recipients.set(memberUid, memberUid === purchaserUid ? "purchaser" : "household_member");
      }
    }
  }
  return {recipients, householdId, duoSeatAssigneeUid, effectiveState};
}

async function reconcilePurchaseEntitlements(purchase) {
  const data = purchase.data;
  const purchaseTokenHash = purchase.tokenHash;
  const purchaserUid = String(data.purchaserUid || "").trim();
  if (!purchaserUid) {
    await removePurchaseCoverage(purchaseTokenHash);
    return;
  }

  const result = await entitlementRecipientsForPurchase(purchase);
  const desiredUids = new Set(result.recipients.keys());
  let previousUids = Array.isArray(data.coveredUids) ?
    data.coveredUids.filter((value) => typeof value === "string") : [];
  if (previousUids.length === 0) {
    const existing = await db.collection("billingCoverage")
        .where("sourcePurchaseTokenHash", "==", purchaseTokenHash).get();
    previousUids = existing.docs
        .map((document) => document.data().recipientUid)
        .filter((value) => typeof value === "string");
  }
  const affectedUids = new Set([...previousUids, ...desiredUids]);
  const batch = db.batch();

  for (const uid of previousUids) {
    if (!desiredUids.has(uid)) {
      batch.delete(db.collection("billingCoverage").doc(coverageDocId(purchaseTokenHash, uid)));
    }
  }
  for (const [uid, seatRole] of result.recipients.entries()) {
    batch.set(
        db.collection("billingCoverage").doc(coverageDocId(purchaseTokenHash, uid)),
        coverageDocument({
          plan: data.plan,
          state: result.effectiveState,
          purchaserUid,
          purchaseTokenHash,
          recipientUid: uid,
          seatRole,
          householdId: result.householdId,
          duoSeatAssigneeUid: result.duoSeatAssigneeUid,
          validUntil: data.validUntil || null,
        }),
        {merge: false},
    );
  }

  batch.set(purchase.ref, {
    coveredUids: [...desiredUids],
    ...(result.householdId ? {householdId: result.householdId} : {householdId: FieldValue.delete()}),
    updatedAt: FieldValue.serverTimestamp(),
  }, {merge: true});
  await batch.commit();
  await Promise.all([...affectedUids].map((uid) => recomputeEntitlement(uid)));
}

async function removePurchaseCoverage(purchaseTokenHash) {
  const purchaseRef = db.collection("billingPurchases").doc(purchaseTokenHash);
  const purchase = await purchaseRef.get();
  let coveredUids = purchase.exists && Array.isArray(purchase.data().coveredUids) ?
    purchase.data().coveredUids.filter((value) => typeof value === "string") : [];
  const existing = await db.collection("billingCoverage")
      .where("sourcePurchaseTokenHash", "==", purchaseTokenHash).get();
  if (coveredUids.length === 0) {
    coveredUids = existing.docs
        .map((document) => document.data().recipientUid)
        .filter((value) => typeof value === "string");
  }
  const affectedUids = new Set(coveredUids);
  const batch = db.batch();
  existing.docs.forEach((document) => batch.delete(document.ref));
  if (purchase.exists) {
    batch.set(purchaseRef, {
      coveredUids: [],
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: true});
  }
  await batch.commit();
  await Promise.all([...affectedUids].map((uid) => recomputeEntitlement(uid)));
}

async function removeRecipientCoverage(uid) {
  const snapshot = await db.collection("billingCoverage")
      .where("recipientUid", "==", uid).get();
  const batch = db.batch();
  for (const document of snapshot.docs) {
    batch.delete(document.ref);
    const tokenHash = String(document.data().sourcePurchaseTokenHash || "").trim();
    if (tokenHash) {
      batch.set(db.collection("billingPurchases").doc(tokenHash), {
        coveredUids: FieldValue.arrayRemove(uid),
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
    }
  }
  batch.delete(db.collection("entitlements").doc(uid));
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
  const state = effectivePlayState(
      normalizePlayState(playPurchase.subscriptionState),
      identity.validUntil,
  );
  const linkedPurchaseToken = String(playPurchase.linkedPurchaseToken || "").trim();
  const linkedTokenHash = linkedPurchaseToken ? sha256(linkedPurchaseToken) : null;
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
    const existingPurchase = await transaction.get(purchaseRef);
    const accountSnapshot = await transaction.get(accountRef);
    const linkSnapshot = await transaction.get(linkRef);
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
    let currentPurchase = null;
    if (previousTokenHash && previousTokenHash !== purchaseTokenHash) {
      currentPurchase = await transaction.get(
          db.collection("billingPurchases").doc(previousTokenHash),
      );
    }
    const existingData = existingPurchase.exists ? existingPurchase.data() : {};
    const currentData = currentPurchase && currentPurchase.exists ?
      currentPurchase.data() : {};
    if (!canAdoptCanonicalPurchase({
      currentTokenHash: previousTokenHash,
      incomingTokenHash: purchaseTokenHash,
      linkedTokenHash,
      currentPurchaseKnown: Boolean(currentPurchase && currentPurchase.exists),
      currentState: currentData.state,
      currentValidUntil: currentData.validUntil,
      incomingSupersededByTokenHash:
        String(existingData.supersededByTokenHash || "").trim() || null,
    })) {
      throw new HttpsError(
          "failed-precondition",
          "This Google Play purchase cannot replace the current Homi+ subscription.",
      );
    }

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
      basePlanId,
      plan: identity.plan,
      state,
      validUntil: identity.validUntil,
      linkedPurchaseTokenHash: linkedTokenHash,
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

  const finalSnapshot = await purchaseRef.get();
  await reconcilePurchaseEntitlements({
    ref: purchaseRef,
    tokenHash: purchaseTokenHash,
    data: finalSnapshot.data(),
  });

  if (previousTokenHash && previousTokenHash !== purchaseTokenHash) {
    await removePurchaseCoverage(previousTokenHash);
  }

  // Entitlement is based on authoritative verified Play state. Acknowledgement
  // is the next server action, not the authority for the purchase itself. Doing
  // coverage reconciliation first also prevents a failed acknowledgement call
  // from leaving a superseded higher-tier purchase as the visible Homi grant.
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
  const identity = purchaseIdentity(playPurchase);
  const freshState = effectivePlayState(
      normalizePlayState(playPurchase.subscriptionState),
      identity.validUntil,
  );
  const stored = await db.collection("billingPurchases").doc(purchaseTokenHash).get();

  if (stored.exists && stored.data().supersededByTokenHash) {
    await stored.ref.set({
      state: freshState,
      validUntil: identity.validUntil,
      acknowledgementState: playPurchase.acknowledgementState || null,
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: true});
    await removePurchaseCoverage(purchaseTokenHash);
    return {
      ignoredSuperseded: true,
      purchaserUid: String(stored.data().purchaserUid || "").trim() || null,
    };
  }

  let resolvedUid = purchaserUid;
  if (!resolvedUid && stored.exists) {
    resolvedUid = String(stored.data().purchaserUid || "").trim() || null;
  }
  if (!resolvedUid) {
    resolvedUid = await resolveUidFromPlay(playPurchase);
  }
  if (!resolvedUid) {
    logger.warn("Homi billing RTDN could not resolve a Homi account", {purchaseTokenHash});
    return null;
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
      await requireBillingRateLimit(user.uid, "billing_verify_hour", 30);
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
      await requireBillingRateLimit(user.uid, "billing_duo_seat_hour", 30);
      const purchase = await currentPurchaseForPurchaser(user.uid);
      const purchaseState = purchase ?
        effectivePlayState(purchase.data.state, purchase.data.validUntil) : null;
      if (
        !purchase ||
        purchase.data.plan !== "duo" ||
        !grantsPaidAccess(purchaseState)
      ) {
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
      if (requestedUid && currentUid !== requestedUid && canReassignAt > Date.now()) {
        throw new HttpsError(
            "failed-precondition",
            "The second Duo seat cannot be reassigned yet.",
        );
      }

      const update = {
        updatedAt: FieldValue.serverTimestamp(),
      };
      if (!requestedUid) {
        update.duoSecondaryUid = FieldValue.delete();
        // Keep the existing cooldown. Unassigning a seat must not become a way
        // to bypass the seven-day reassignment boundary.
      } else if (currentUid !== requestedUid) {
        update.duoSecondaryUid = requestedUid;
        update.duoCanReassignAt = Timestamp.fromMillis(
            Date.now() + DUO_REASSIGNMENT_COOLDOWN_DAYS * 24 * 60 * 60 * 1000,
        );
      }
      await accountRef.set(update, {merge: true});
      const refreshedPurchase = await purchase.ref.get();
      await reconcilePurchaseEntitlements({
        ref: purchase.ref,
        tokenHash: purchase.tokenHash,
        data: refreshedPurchase.data(),
      });
      const refreshedAccount = await accountRef.get();
      const next = refreshedAccount.data() && refreshedAccount.data().duoCanReassignAt;
      return {
        assigned: Boolean(requestedUid),
        canReassignAt: next && typeof next.toDate === "function" ?
          next.toDate().toISOString() : null,
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
      const before = event.data && event.data.before && event.data.before.exists ?
        event.data.before.data() : null;
      const after = event.data && event.data.after && event.data.after.exists ?
        event.data.after.data() : null;
      const candidates = new Set();
      for (const data of [before, after]) {
        if (!data) continue;
        if (typeof data.ownerUid === "string" && data.ownerUid) candidates.add(data.ownerUid);
        if (Array.isArray(data.memberUids)) {
          data.memberUids.forEach((uid) => {
            if (typeof uid === "string" && uid) candidates.add(uid);
          });
        }
      }

      const attached = await db.collection("billingPurchases")
          .where("householdId", "==", householdId).get();
      for (const document of attached.docs) {
        const data = document.data();
        if (data.plan !== "household" || data.supersededByTokenHash) continue;
        await reconcilePurchaseEntitlements({
          ref: document.ref,
          tokenHash: document.id,
          data,
        });
      }

      for (const uid of candidates) {
        const purchase = await currentPurchaseForPurchaser(uid);
        const purchaseState = purchase ?
          effectivePlayState(purchase.data.state, purchase.data.validUntil) : null;
        if (
          !purchase ||
          purchase.data.plan !== "household" ||
          !grantsPaidAccess(purchaseState)
        ) {
          continue;
        }
        await reconcilePurchaseEntitlements(purchase);
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
            // Preserve duoCanReassignAt so connection removal cannot bypass the
            // seven-day seat reassignment boundary.
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

      // One Homi account can accumulate historical purchase-token documents
      // across plan replacements. Account deletion must remove the account link
      // and every Homi-side purchase association, not just today's active token.
      const ownedPurchases = await db.collection("billingPurchases")
          .where("purchaserUid", "==", uid).get();
      for (const purchase of ownedPurchases.docs) {
        await removePurchaseCoverage(purchase.id);
        await purchase.ref.set({
          purchaseToken: FieldValue.delete(),
          purchaserUid: FieldValue.delete(),
          coveredUids: [],
          accountDeletedAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        }, {merge: true});
      }

      // Also remove coverage this user received from somebody else's Homi+
      // purchase. That does not alter the other payer's remaining recipients.
      await removeRecipientCoverage(uid);

      const secondaryAssignments = await db.collection("billingAccounts")
          .where("duoSecondaryUid", "==", uid).get();
      const batch = db.batch();
      batch.delete(db.collection("billingAccountLinks").doc(accountId));
      batch.delete(accountRef);
      secondaryAssignments.docs.forEach((document) => {
        batch.set(document.ref, {
          duoSecondaryUid: FieldValue.delete(),
          // Preserve the payer's existing reassignment cooldown.
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
