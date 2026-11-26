'use strict';

const express = require('express');
const groupController = require('../controllers/groupController');
const { requireAuth } = require('../middleware/auth');
const { validate } = require('../middleware/validate');
const {
  createGroupSchema,
  updateGroupSchema,
  addMembersSchema,
  setAdminSchema,
} = require('../validators/groupValidators');

const router = express.Router();

router.use(requireAuth);

router.post('/', validate({ body: createGroupSchema }), groupController.createGroup);
router.get('/:id', groupController.getGroup);
router.patch('/:id', validate({ body: updateGroupSchema }), groupController.updateGroup);
router.post('/:id/members', validate({ body: addMembersSchema }), groupController.addMembers);
router.delete('/:id/members/:userId', groupController.removeMember);
router.post('/:id/admins', validate({ body: setAdminSchema }), groupController.setAdmin);
router.post('/:id/leave', groupController.leaveGroup);
router.delete('/:id', groupController.deleteGroup);

module.exports = router;
