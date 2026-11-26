'use strict';

const http = require('http');
const { createApp } = require('./app');
const { env, validateEnv } = require('./config/env');
const { connectDB, disconnectDB } = require('./config/db');
const { initFirebase } = require('./config/firebase');
const { initSocket } = require('./sockets');
const logger = require('./config/logger');

async function start() {
  validateEnv();
  initFirebase();

  const app = createApp();
  const server = http.createServer(app);
  initSocket(server);

  try {
    await connectDB();
  } catch (_err) {
    logger.error('[server] continuing without database — persistence unavailable');
  }

  server.listen(env.port, '0.0.0.0', () => {
    logger.info(`[server] Miyu API listening on :${env.port} (${env.nodeEnv})`);
  });

  const shutdown = async (signal) => {
    logger.info(`[server] ${signal} received, shutting down`);
    server.close(async () => {
      await disconnectDB().catch(() => {});
      process.exit(0);
    });
    setTimeout(() => process.exit(1), 10_000).unref();
  };

  process.on('SIGTERM', () => shutdown('SIGTERM'));
  process.on('SIGINT', () => shutdown('SIGINT'));
  process.on('unhandledRejection', (reason) => {
    logger.error({ err: String(reason) }, '[server] unhandled rejection');
  });

  return server;
}

if (require.main === module) {
  start().catch((err) => {
    logger.error({ err: err.message }, '[server] fatal startup error');
    process.exit(1);
  });
}

module.exports = { start };
