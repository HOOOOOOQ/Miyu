'use strict';

const express = require('express');
const chatController = require('../controllers/chatController');
const { requireAuth } = require('../middleware/auth');
const { validate } = require('../middleware/validate');
const { createChatSchema } = require('../validators/chatValidators');

const router = express.Router();

router.use(requireAuth);

router.get('/', chatController.listChats);
router.post('/', validate({ body: createChatSchema }), chatController.createChat);
router.get('/:id', chatController.getChat);
router.delete('/:id', chatController.deleteChat);
router.post('/:id/archive', chatController.archiveChat);
router.post('/:id/pin', chatController.pinChat);
router.post('/:id/mute', chatController.muteChat);
router.get('/:id/messages', chatController.listMessages);
router.post('/:id/read', chatController.markRead);
router.post('/:id/delivered', chatController.markDelivered);

module.exports = router;
