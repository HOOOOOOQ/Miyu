'use strict';

const express = require('express');
const callController = require('../controllers/callController');
const { requireAuth } = require('../middleware/auth');
const { validate } = require('../middleware/validate');
const { createCallSchema, endCallSchema } = require('../validators/callValidators');

const router = express.Router();

router.use(requireAuth);

router.post('/', validate({ body: createCallSchema }), callController.createCall);
router.get('/history', callController.history);
router.get('/ice-servers', callController.iceServers);
router.get('/:id', callController.getCall);
router.post('/:id/accept', callController.acceptCall);
router.post('/:id/reject', callController.rejectCall);
router.post('/:id/busy', callController.busyCall);
router.post('/:id/end', validate({ body: endCallSchema.partial() }), callController.endCall);

module.exports = router;
