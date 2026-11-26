'use strict';

const express = require('express');
const authController = require('../controllers/authController');
const { validate } = require('../middleware/validate');
const { requireAuth } = require('../middleware/auth');
const { authLimiter } = require('../middleware/rateLimit');
const { googleLoginSchema, refreshSchema, logoutSchema } = require('../validators/authValidators');

const router = express.Router();

router.post('/google', authLimiter, validate({ body: googleLoginSchema }), authController.googleLogin);
router.post('/refresh', authLimiter, validate({ body: refreshSchema }), authController.refresh);
router.post('/logout', requireAuth, validate({ body: logoutSchema }), authController.logout);

module.exports = router;
