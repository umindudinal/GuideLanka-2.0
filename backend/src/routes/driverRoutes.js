const express = require('express');
const router = express.Router();
const driverController = require('../controllers/driverController');
const authMiddleware = require('../middlewares/authMiddleware');
const authorizeRoles = require('../middlewares/roleMiddleware');

router.get('/profile', authMiddleware, driverController.getDriverProfile);

router.put('/profile', authMiddleware, driverController.updateDriverProfile);

router.patch('/status', authMiddleware, driverController.updateDriverStatus);

router.post('/profile/picture', authMiddleware, driverController.uploadProfilePicture);

router.get('/:driverId/reviews', driverController.getDriverReviews);

router.post('/:driverId/reviews', driverController.addDriverReview);

router.put('/:driverId', authMiddleware, authorizeRoles('AUTHORITY', 'ADMIN'), driverController.updateDriverByAdmin);

router.delete('/:driverId', authMiddleware, authorizeRoles('AUTHORITY', 'ADMIN'), driverController.deleteDriver);

module.exports = router;
