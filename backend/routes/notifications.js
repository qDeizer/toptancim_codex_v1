const router = require('express').Router();
const notificationController = require('../controllers/notificationController');
const authorize = require('../middleware/auth');

router.get('/', authorize, notificationController.getNotifications);
router.get('/unread-count', authorize, notificationController.getUnreadCount);
router.post('/mark-read/:notificationId', authorize, notificationController.markAsRead);

module.exports = router;
