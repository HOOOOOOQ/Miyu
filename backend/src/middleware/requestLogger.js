'use strict';

const pinoHttp = require('pino-http');
const logger = require('../config/logger');

const requestLogger = pinoHttp({
  logger,
  autoLogging: {
    ignore: (req) => req.url === '/api/health',
  },
  genReqId: (req) => req.headers['x-request-id'] || undefined,
  customLogLevel: (_req, res, err) => {
    if (err || res.statusCode >= 500) return 'error';
    if (res.statusCode >= 400) return 'warn';
    return 'info';
  },
  redact: ['req.headers.authorization', 'req.headers.cookie'],
});

module.exports = { requestLogger };
