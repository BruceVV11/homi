const {test} = require("node:test");
const assert = require("node:assert/strict");
const {
  planCanonicalMembershipUpdate,
  canReopenTask,
  canRemoveBeforeHistoryExpires,
} = require("./household_task_policy");

test("migrated audience-version-0 tasks are never widened", () => {
  const update = planCanonicalMembershipUpdate({
    audienceVersion: 0,
    memberUids: ["alice", "bob"],
    assigneeUid: "bob",
  }, ["alice", "bob", "charlie"]);
  assert.equal(update, null);
});

test("canonical audience-version-1 tasks follow current Household members", () => {
  const update = planCanonicalMembershipUpdate({
    audienceVersion: 1,
    memberUids: ["alice", "bob"],
    assigneeUid: "bob",
    completedByUid: "bob",
  }, ["alice", "charlie"]);
  assert.deepEqual(update, {
    memberUids: ["alice", "charlie"],
    assigneeUid: null,
    assigneeName: "Unassigned",
    completedByUid: null,
    completedByName: "Former Household member",
  });
});

test("canonical membership update retains valid attribution", () => {
  const update = planCanonicalMembershipUpdate({
    audienceVersion: 1,
    memberUids: ["alice", "bob"],
    assigneeUid: "bob",
    completedByUid: "alice",
  }, ["alice", "bob", "charlie"]);
  assert.deepEqual(update, {
    memberUids: ["alice", "bob", "charlie"],
  });
});

test("Household owner can recover a completed task after creator/completer absence", () => {
  const data = {createdByUid: "former", completedByUid: "former"};
  assert.equal(canReopenTask(data, "owner", true), true);
  assert.equal(canReopenTask(data, "member", false), false);
});

test("creator or Household owner can remove active task, normal member cannot", () => {
  const data = {createdByUid: "creator"};
  assert.equal(canRemoveBeforeHistoryExpires(data, "creator", false), true);
  assert.equal(canRemoveBeforeHistoryExpires(data, "owner", true), true);
  assert.equal(canRemoveBeforeHistoryExpires(data, "member", false), false);
});
