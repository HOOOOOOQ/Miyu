'use strict';

const ApiError = require('../utils/ApiError');
const logger = require('../config/logger');

function notFoundHandler(req, _res, next) {
  next(ApiError.notFound(`Route ${req.method} ${req.originalUrl} not found`, 'ROUTE_NOT_FOUND'));
}

// eslint-disable-next-line no-unused-vars
function errorHandler(err, req, res, _next) {
  let status = err.statusCode || 500;
  let code = err.code || 'INTERNAL_ERROR';
  let message = err.message || 'Internal server error';
  let details = err.details;

  if (err.name === 'CastError') {
    status = 400;
    code = 'INVALID_ID';
    message = 'Invalid identifier format';
  } else if (err.name === 'ValidationError' && err.errors) {
    status = 400;
    code = 'VALIDATION_ERROR';
    message = 'Database validation failed';
    details = Object.values(err.errors).map((e) => ({ path: e.path, message: e.message }));
  } else if (err.code === 11000) {
    status = 409;
    code = 'DUPLICATE_KEY';
    message = 'A record with those unique fields already exists';
  } else if (err.type === 'entity.too.large') {
    status = 413;
    code = 'PAYLOAD_TOO_LARGE';
    message = 'Request payload too large';
  }

  if (status >= 500) {
    logger.error({ err, path: req.originalUrl, method: req.method }, '[error] unhandled');
  } else {
    logger.warn({ status, code, path: req.originalUrl, method: req.method, message }, '[error] handled');
  }

  const body = { success: false, error: { code, message } };
  if (details) body.error.details = details;
  if (process.env.NODE_ENV === 'development' && status >= 500) body.error.stack = err.stack;
  res.status(status).json(body);
}

module.exports = { errorHandler, notFoundHandler };
