const {onDocumentUpdated} = require("firebase-functions/v2/firestore");
const logger = require("firebase-functions/logger");
const {getFirestore, FieldValue} = require("firebase-admin/firestore");
const {
  planCanonicalMembershipUpdate,
} = require("./household_task_policy");

const db = getFirestore();
const BATCH_SIZE = 400;

function cleanUids(value) {
  if (!Array.isArray(value)) return [];
  return [...new Set(value
      .filter((uid) => typeof uid === "string" && uid.trim())
      .map((uid) => uid.trim()))].sort();
}

function sameUids(first, second) {
  if (first.length !== second.length) return false;
  return first.every((uid, index) => uid === second[index]);
}

// New 0.12 Tasks are audienceVersion 1 and intentionally follow the current
// canonical Household membership. Migrated pre-0.12 Tasks are audienceVersion
// 0: their safe recipient list is the intersection of the historic audience
// and the Household at migration time, so this trigger must never widen them
// when somebody joins later.
exports.onHouseholdTaskMembershipChanged = onDocumentUpdated(
    "households/{householdId}",
    async (event) => {
      const before = event.data && event.data.before.data();
      const after = event.data && event.data.after.data();
      if (!before || !after) return;

      const previousMembers = cleanUids(before.memberUids);
      const nextMembers = cleanUids(after.memberUids);
      if (sameUids(previousMembers, nextMembers)) return;

      const householdId = event.params.householdId;
      try {
        const tasks = await db.collection("sharedTasks")
            .where("householdId", "==", householdId)
            .get();
        const planned = tasks.docs
            .map((document) => ({
              document,
              update: planCanonicalMembershipUpdate(
                  document.data(),
                  nextMembers,
              ),
            }))
            .filter((item) => item.update !== null);
        if (planned.length === 0) return;

        for (let start = 0; start < planned.length; start += BATCH_SIZE) {
          const batch = db.batch();
          planned.slice(start, start + BATCH_SIZE).forEach((item) => {
            batch.update(item.document.ref, {
              ...item.update,
              updatedAt: FieldValue.serverTimestamp(),
            });
          });
          await batch.commit();
        }
      } catch (error) {
        logger.error("Homi shared-task membership sync failed", {
          householdId,
          previousMembers,
          nextMembers,
          error: error && error.message,
        });
        throw error;
      }
    },
);
