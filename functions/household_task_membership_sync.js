const {onDocumentUpdated} = require("firebase-functions/v2/firestore");
const logger = require("firebase-functions/logger");
const {getFirestore, FieldValue} = require("firebase-admin/firestore");

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

// New 0.12 shared Tasks carry householdId. Keep their visibility aligned with
// current canonical membership rather than freezing the member list at task
// creation time. Legacy pre-0.12 Tasks without householdId are intentionally
// left unchanged because automatically broadening their audience could expose
// a task that was shared under the old preference-based model.
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
        if (tasks.empty) return;

        for (let start = 0; start < tasks.docs.length; start += BATCH_SIZE) {
          const batch = db.batch();
          tasks.docs.slice(start, start + BATCH_SIZE).forEach((document) => {
            const data = document.data();
            const update = {
              memberUids: nextMembers,
              updatedAt: FieldValue.serverTimestamp(),
            };

            if (data.assigneeUid && !nextMembers.includes(data.assigneeUid)) {
              update.assigneeUid = null;
              update.assigneeName = "Unassigned";
            }
            if (data.completedByUid &&
                !nextMembers.includes(data.completedByUid)) {
              update.completedByUid = null;
              update.completedByName = "Former Household member";
            }

            batch.update(document.ref, update);
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
