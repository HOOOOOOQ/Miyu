'use strict';

const express = require('express');
const userController = require('../controllers/userController');
const { requireAuth } = require('../middleware/auth');
const { validate } = require('../middleware/validate');
const {
  updateMeSchema,
  searchQuerySchema,
  blockSchema,
  reportSchema,
  registerDeviceSchema,
  unregisterDeviceSchema,
} = require('../validators/userValidators');

const router = express.Router();

router.use(requireAuth);

router.get('/me', userController.getMe);
router.patch('/me', validate({ body: updateMeSchema }), userController.updateMe);
router.delete('/me', userController.deleteMe);
router.get('/search', validate({ query: searchQuerySchema }), userController.searchUsers);
router.post('/devices', validate({ body: registerDeviceSchema }), userController.registerDevice);
router.delete('/devices', validate({ body: unregisterDeviceSchema }), userController.unregisterDevice);
router.post('/:id/block', validate({ body: blockSchema }), userController.blockUser);
router.delete('/:id/block', userController.unblockUser);
router.post('/:id/report', validate({ body: reportSchema }), userController.reportUser);
router.get('/:id', userController.getUserById);

module.exports = router;
