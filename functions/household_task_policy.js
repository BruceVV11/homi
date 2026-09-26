const CANONICAL_AUDIENCE_VERSION = 1;

function planCanonicalMembershipUpdate(data, nextMembers) {
  if (!data || Number(data.audienceVersion) !== CANONICAL_AUDIENCE_VERSION) {
    return null;
  }

  const update = {memberUids: [...nextMembers]};
  if (data.assigneeUid && !nextMembers.includes(data.assigneeUid)) {
    update.assigneeUid = null;
    update.assigneeName = "Unassigned";
  }
  if (data.completedByUid && !nextMembers.includes(data.completedByUid)) {
    update.completedByUid = null;
    update.completedByName = "Former Household member";
  }
  return update;
}

function canReopenTask(data, actorUid, isHouseholdOwner) {
  return Boolean(data && (
    data.createdByUid === actorUid ||
    data.completedByUid === actorUid ||
    isHouseholdOwner
  ));
}

function canRemoveBeforeHistoryExpires(data, actorUid, isHouseholdOwner) {
  return Boolean(data && (
    data.createdByUid === actorUid ||
    isHouseholdOwner
  ));
}

module.exports = {
  CANONICAL_AUDIENCE_VERSION,
  planCanonicalMembershipUpdate,
  canReopenTask,
  canRemoveBeforeHistoryExpires,
};
