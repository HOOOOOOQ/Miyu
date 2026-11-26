'use strict';

const express = require('express');
const messageController = require('../controllers/messageController');
const chatController = require('../controllers/chatController');
const { requireAuth } = require('../middleware/auth');
const { validate } = require('../middleware/validate');
const {
  sendMessageSchema,
  editMessageSchema,
  deleteMessageSchema,
  reactionSchema,
} = require('../validators/chatValidators');
const { z } = require('zod');
const { objectId } = require('../validators/userValidators');

const router = express.Router();

router.use(requireAuth);

router.post('/', validate({ body: sendMessageSchema }), chatController.sendMessage);
router.patch('/:id', validate({ body: editMessageSchema }), messageController.editMessage);
router.delete('/:id', validate({ body: deleteMessageSchema }), messageController.deleteMessage);
router.post('/:id/reactions', validate({ body: reactionSchema }), messageController.react);
router.post(
  '/:id/forward',
  validate({ body: z.object({ conversationIds: z.array(objectId).min(1).max(10) }) }),
  messageController.forwardMessage
);

module.exports = router;
