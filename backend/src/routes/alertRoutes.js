const express = require('express');
const { receiveAlert, createSOSAlert, getActiveAlerts } = require('../controllers/alertController');
const authMiddleware = require('../middlewares/authMiddleware');
const router = express.Router();

router.post('/', authMiddleware, receiveAlert);

router.post('/sos', authMiddleware, createSOSAlert);

router.get('/', getActiveAlerts);

module.exports = router;
