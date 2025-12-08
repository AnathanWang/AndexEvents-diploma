import express from 'express';
import { authMiddleware } from '../middleware/auth.middleware.js';
import * as userController from '../controllers/user.controller.js';

const router = express.Router();

// Публичный endpoint (без авторизации)
router.post('/', userController.createUser);

// Защищенные endpoints (требуют авторизации через Firebase token)
router.get('/me', authMiddleware, userController.getCurrentUser);
router.put('/me', authMiddleware, userController.updateProfile);
router.put('/me/location', authMiddleware, userController.updateLocation);

export default router;
