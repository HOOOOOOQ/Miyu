'use strict';

const express = require('express');

const router = express.Router();

router.use('/auth', require('./authRoutes'));
router.use('/users', require('./userRoutes'));
router.use('/chats', require('./chatRoutes'));
router.use('/messages', require('./messageRoutes'));
router.use('/groups', require('./groupRoutes'));
router.use('/calls', require('./callRoutes'));
router.use('/media', require('./mediaRoutes'));
router.use('/notifications', require('./notificationRoutes'));

module.exports = router;
