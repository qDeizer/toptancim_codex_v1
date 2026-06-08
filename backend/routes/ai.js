const express = require('express');
const router = express.Router();
const aiController = require('../controllers/aiController');
const auth = require('../middleware/auth');

router.get('/settings', auth, aiController.getSettings);
router.put('/settings', auth, aiController.updateSettings);
router.post('/chat', auth, aiController.chat);

module.exports = router;
