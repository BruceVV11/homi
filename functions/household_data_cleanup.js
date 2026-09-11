const {onDocumentDeleted} = require("firebase-functions/v2/firestore");
const logger = require("firebase-functions/logger");
const {getFirestore} = require("firebase-admin/firestore");

const db = getFirestore();
const DELETE_BATCH_SIZE = 400;

async function deleteQueryInBatches(query) {
  let removed = 0;
  while (true) {
    const snapshot = await query.limit(DELETE_BATCH_SIZE).get();
    if (snapshot.empty) return removed;
    const batch = db.batch();
    snapshot.docs.forEach((document) => batch.delete(document.ref));
    await batch.commit();
    removed += snapshot.size;
    if (snapshot.size < DELETE_BATCH_SIZE) return removed;
  }
}

// Firestore does not recursively delete subcollections when a Household parent
// document is removed. Keep the canonical data plane and its newer shared-task
// records from becoming unreachable paid storage after the Household is gone.
exports.onHomiHouseholdDeletedDataCleanup = onDocumentDeleted(
    "households/{householdId}",
    async (event) => {
      const householdId = event.params.householdId;
      try {
        const householdData = db.collection("households")
            .doc(householdId).collection("data");
        const [dataRemoved, tasksRemoved] = await Promise.all([
          deleteQueryInBatches(householdData),
          deleteQueryInBatches(
              db.collection("sharedTasks")
                  .where("householdId", "==", householdId),
          ),
        ]);
        logger.info("Deleted Homi Household shared data", {
          householdId,
          dataRemoved,
          tasksRemoved,
        });
      } catch (error) {
        logger.error("Homi Household shared-data cleanup failed", {
          householdId,
          error: error && error.message,
        });
        throw error;
      }
    },
);
