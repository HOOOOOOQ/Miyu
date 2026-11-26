'use strict';

// Pterodactyl runs the startup command from the panel, which is `node index.js`
// for the generic Node.js egg — it does not read the "main" field of
// package.json. Local dev, Docker and CI still run src/server.js directly.
const { start } = require('./src/server');
const logger = require('./src/config/logger');

// Only boot when executed (`node index.js`); requiring this file must stay
// side-effect free so tests can assert the entry point exists.
if (require.main === module) {
  start().catch((err) => {
    logger.error({ err: err.message }, '[index] fatal startup error');
    process.exit(1);
  });
}

module.exports = { start };
