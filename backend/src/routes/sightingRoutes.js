const express = require('express');
const { logSighting, getSightings } = require('../controllers/sightingController');
const authMiddleware = require('../middlewares/authMiddleware');
const authorizeRoles = require('../middlewares/roleMiddleware');

const router = express.Router();

router.post('/', authMiddleware, authorizeRoles('DRIVER', 'AUTHORITY', 'ADMIN'), logSighting);

router.get('/', getSightings);

module.exports = router;
