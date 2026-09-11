const {onDocumentUpdated} = require("firebase-functions/v2/firestore");
const logger = require("firebase-functions/logger");
const {getFirestore, FieldValue} = require("firebase-admin/firestore");

const db = getFirestore();

function cleanDisplayName(data) {
  const value = data && typeof data.displayName === "string" ?
    data.displayName.trim() : "";
  return value ? value.slice(0, 80) : "Homi user";
}

/// Keeps pending invitation ownership aligned with the canonical Household
/// owner. This covers explicit ownership transfer and the account-deletion
/// fallback that promotes a remaining member.
exports.onHouseholdOwnershipChanged = onDocumentUpdated(
    "households/{householdId}",
    async (event) => {
      const before = event.data && event.data.before.data();
      const after = event.data && event.data.after.data();
      if (!before || !after) return;

      const previousOwnerUid = typeof before.ownerUid === "string" ?
        before.ownerUid : "";
      const nextOwnerUid = typeof after.ownerUid === "string" ?
        after.ownerUid : "";
      if (!nextOwnerUid || previousOwnerUid === nextOwnerUid) return;

      const householdId = event.params.householdId;
      try {
        const nextOwnerMember = await db.collection("households")
            .doc(householdId)
            .collection("members")
            .doc(nextOwnerUid)
            .get();
        const nextOwnerName = cleanDisplayName(
            nextOwnerMember.exists ? nextOwnerMember.data() : null,
        );

        const invitations = await db.collection("householdInvites")
            .where("householdId", "==", householdId)
            .get();
        if (invitations.empty) return;

        for (let start = 0; start < invitations.docs.length; start += 400) {
          const batch = db.batch();
          invitations.docs.slice(start, start + 400).forEach((document) => {
            batch.set(document.ref, {
              inviterUid: nextOwnerUid,
              inviterName: nextOwnerName,
              updatedAt: FieldValue.serverTimestamp(),
            }, {merge: true});
          });
          await batch.commit();
        }
      } catch (error) {
        logger.error("Homi Household invite-owner sync failed", {
          householdId,
          previousOwnerUid,
          nextOwnerUid,
          error: error && error.message,
        });
      }
    },
);
