// Load the main Homi Functions module first so it initializes Firebase Admin
// and establishes global 2nd-gen runtime options before supplementary modules
// are defined.
const core = require("./index");
const checkIn = require("./check_in");
const connectionCleanup = require("./connection_cleanup");
const deviceRegistration = require("./device_registration");
const savedPlaces = require("./saved_places");
const locationShare = require("./location_share");
const households = require("./households");
const householdInviteOwnerSync = require("./household_invite_owner_sync");
const trustedPeoplePreferences = require("./trusted_people_preferences");
const sharedTasksCanonical = require("./shared_tasks_canonical");
const householdDataCleanup = require("./household_data_cleanup");
const householdTaskMembershipSync = require("./household_task_membership_sync");
const householdSharedTaskNotifications = require("./household_shared_task_notifications");
// Public Play product/base-plan IDs are exact release infrastructure. Load the
// source-controlled catalog before billing.js reads its environment-shaped
// policy input. Blank IDs keep billing fail-closed until Play Console setup.
require("./billing_catalog");
const billing = require("./billing");

// A stale deployed HTTPS function already owned the historical
// `onConnectionDeleted` name. Do not export that obsolete endpoint from the
// current codebase; the replacement Firestore trigger is
// `onTrustedConnectionDeleted` and the deployment helper migrates it safely.
const {
  onConnectionDeleted: deprecatedOnConnectionDeleted,
  onSharedTaskCreated: deprecatedOnSharedTaskCreated,
  onSharedTaskUpdated: deprecatedOnSharedTaskUpdated,
  ...coreWithoutDeprecatedTaskTriggers
} = core;
void deprecatedOnConnectionDeleted;
void deprecatedOnSharedTaskCreated;
void deprecatedOnSharedTaskUpdated;

module.exports = {
  ...coreWithoutDeprecatedTaskTriggers,
  ...checkIn,
  ...connectionCleanup,
  ...deviceRegistration,
  ...savedPlaces,
  // Keep the deployed callable name stable while replacing the older core
  // implementation with the viewer-capped privacy/cost boundary.
  ...locationShare,
  ...households,
  ...householdInviteOwnerSync,
  // Keep the deployed callable name stable while canonical Household
  // membership, rather than a People toggle, determines Household scope.
  ...trustedPeoplePreferences,
  // Shared task names remain stable for existing clients, but the current
  // canonical Household now defines who can create/read/change them.
  ...sharedTasksCanonical,
  ...householdDataCleanup,
  ...householdTaskMembershipSync,
  // Root shared-task triggers are retired only after these nested replacements
  // are deployed and proven ACTIVE.
  ...householdSharedTaskNotifications,
  // Homi+ purchase verification, lifecycle reconciliation and server-written
  // entitlement state. These exports fail closed until the durable Play
  // product/base-plan IDs and Android Publisher access are configured.
  ...billing,
};
