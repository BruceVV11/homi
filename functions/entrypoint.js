// Load the main Homi Functions module first so it initializes Firebase Admin
// and establishes global 2nd-gen runtime options before supplementary modules
// are defined.
const core = require("./index");
const checkIn = require("./check_in");
const connectionCleanup = require("./connection_cleanup");
const deviceRegistration = require("./device_registration");
const savedPlaces = require("./saved_places");

// A stale deployed HTTPS function already owned the historical
// `onConnectionDeleted` name. Do not export that obsolete endpoint from the
// current codebase; the replacement Firestore trigger is
// `onTrustedConnectionDeleted` and the deployment helper migrates it safely.
const {
  onConnectionDeleted: deprecatedOnConnectionDeleted,
  ...coreWithoutDeprecatedConnectionDelete
} = core;
void deprecatedOnConnectionDeleted;

module.exports = {
  ...coreWithoutDeprecatedConnectionDelete,
  ...checkIn,
  ...connectionCleanup,
  ...deviceRegistration,
  ...savedPlaces,
};
