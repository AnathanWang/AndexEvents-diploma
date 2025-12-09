import { Router } from 'express';
import multer from 'multer';
import uploadController from '../controllers/upload.controller.js';
import { authMiddleware } from '../middleware/auth.middleware.js';

const router = Router();

// Configure multer for memory storage
const upload = multer({
    storage: multer.memoryStorage(),
    limits: {
        fileSize: 10 * 1024 * 1024, // 10MB limit
    },
});

// POST /api/upload
router.post('/', authMiddleware, upload.single('file'), uploadController.uploadFile);

export default router;
