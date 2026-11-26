'use strict';

const ApiError = require('../utils/ApiError');

/**
 * Zod validation middleware.
 * @param {{ body?: import('zod').ZodTypeAny, query?: import('zod').ZodTypeAny, params?: import('zod').ZodTypeAny }} schemas
 */
function validate(schemas) {
  return (req, _res, next) => {
    try {
      if (schemas.body) req.body = schemas.body.parse(req.body ?? {});
      if (schemas.query) req.validatedQuery = schemas.query.parse(req.query ?? {});
      if (schemas.params) req.params = schemas.params.parse(req.params ?? {});
      next();
    } catch (err) {
      const details =
        err && err.errors
          ? err.errors.map((e) => ({ path: e.path.join('.'), message: e.message }))
          : undefined;
      next(ApiError.badRequest('Validation failed', 'VALIDATION_ERROR', details));
    }
  };
}

module.exports = { validate };
