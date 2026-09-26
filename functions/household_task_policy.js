const CANONICAL_AUDIENCE_VERSION = 1;

function planCanonicalMembershipUpdate(data, nextMembers) {
  if (!data) return null;

  const audienceVersion = Number(data.audienceVersion);
  const currentMembers = Array.isArray(data.memberUids) ?
    data.memberUids.filter((uid) => typeof uid === "string") : [];

  let memberUids;
  if (audienceVersion === CANONICAL_AUDIENCE_VERSION) {
    memberUids = [...nextMembers];
  } else if (audienceVersion === 0) {
    // Historical audiences are privacy-stable: membership removal may shrink
    // the old audience, but a later Household join must never widen it.
    const nextSet = new Set(nextMembers);
    memberUids = currentMembers.filter((uid) => nextSet.has(uid));
  } else {
    return null;
  }

  const update = {memberUids};
  if (data.assigneeUid && !memberUids.includes(data.assigneeUid)) {
    update.assigneeUid = null;
    update.assigneeName = "Unassigned";
  }
  if (data.completedByUid && !memberUids.includes(data.completedByUid)) {
    update.completedByUid = null;
    update.completedByName = "Former Household member";
  }

  const unchangedMembers = currentMembers.length === memberUids.length &&
    currentMembers.every((uid, index) => uid === memberUids[index]);
  const onlyMembers = Object.keys(update).length === 1;
  return unchangedMembers && onlyMembers ? null : update;
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
