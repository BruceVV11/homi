const {onDocumentDeleted} = require("firebase-functions/v2/firestore");
const logger = require("firebase-functions/logger");
const {getFirestore, FieldValue} = require("firebase-admin/firestore");

const db = getFirestore();

async function detachMemberFromCreatorTasks(creatorUid, memberUid) {
  const snapshot = await db.collection("sharedTasks")
      .where("createdByUid", "==", creatorUid).get();
  const affected = snapshot.docs.filter((document) => {
    const members = document.data().memberUids;
    return Array.isArray(members) && members.includes(memberUid);
  });

  for (let start = 0; start < affected.length; start += 400) {
    const batch = db.batch();
    affected.slice(start, start + 400).forEach((document) => {
      const data = document.data();
      const members = data.memberUids.filter((uid) => uid !== memberUid);
      const update = {
        memberUids: members,
        updatedAt: FieldValue.serverTimestamp(),
      };
      if (data.assigneeUid === memberUid) {
        update.assigneeUid = null;
        update.assigneeName = "Unassigned";
      }
      if (data.completedByUid === memberUid) {
        update.completedByUid = null;
        update.completedByName = "Former Homi user";
      }
      batch.update(document.ref, update);
    });
    await batch.commit();
  }
}

async function revokeSharedPlaceViewer(ownerUid, viewerUid) {
  const places = db.collection("sharedPlaces").doc(ownerUid)
      .collection("places");
  for (const kind of ["home", "work"]) {
    const ref = places.doc(kind);
    const snapshot = await ref.get();
    if (!snapshot.exists) continue;
    const data = snapshot.data();
    const viewers = Array.isArray(data.viewerUids) ? data.viewerUids : [];
    if (!viewers.includes(viewerUid)) continue;
    const remaining = viewers.filter((uid) => uid !== viewerUid);
    if (remaining.length === 0) {
      await ref.delete();
    } else {
      await ref.update({
        viewerUids: remaining,
        updatedAt: FieldValue.serverTimestamp(),
      });
    }
  }
}

async function cleanupConnectionMetadata(firstUid, secondUid) {
  // Remove precise saved-place visibility before deleting the location-share
  // metadata. Firestore also requires an active share at read time, but this
  // cleanup prevents a future reconnect/re-share from reviving a stale grant.
  await Promise.all([
    revokeSharedPlaceViewer(firstUid, secondUid),
    revokeSharedPlaceViewer(secondUid, firstUid),
  ]);

  const refs = [
    db.collection("locationShares").doc(firstUid)
        .collection("viewers").doc(secondUid),
    db.collection("locationShares").doc(secondUid)
        .collection("viewers").doc(firstUid),
    db.collection("peoplePreferences").doc(firstUid)
        .collection("people").doc(secondUid),
    db.collection("peoplePreferences").doc(secondUid)
        .collection("people").doc(firstUid),
    db.collection("heartCooldowns").doc(`${firstUid}_${secondUid}`),
    db.collection("heartCooldowns").doc(`${secondUid}_${firstUid}`),
  ];
  const batch = db.batch();
  refs.forEach((ref) => batch.delete(ref));
  await batch.commit();
}

async function cleanupConnectionState(firstUid, secondUid) {
  await detachMemberFromCreatorTasks(firstUid, secondUid);
  await detachMemberFromCreatorTasks(secondUid, firstUid);
  await cleanupConnectionMetadata(firstUid, secondUid);
}

// This renamed trigger replaces a stale deployed HTTPS function that used the
// old onConnectionDeleted name. Keep this export name stable after migration.
exports.onTrustedConnectionDeleted = onDocumentDeleted(
    "connections/{connectionId}",
    async (event) => {
      const data = event.data && event.data.data();
      if (!data || !data.aUid || !data.bUid) return;
      try {
        await cleanupConnectionState(data.aUid, data.bUid);
      } catch (error) {
        logger.error("Homi connection cleanup failed", {
          connectionId: event.params.connectionId,
          error: error && error.message,
        });
      }
    },
);
