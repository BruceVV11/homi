// Load the main Homi Functions module first so it initializes Firebase Admin
// and establishes global 2nd-gen runtime options before supplementary callable
// modules are defined.
const core = require("./index");
const deviceRegistration = require("./device_registration");

module.exports = {
  ...core,
  ...deviceRegistration,
};
