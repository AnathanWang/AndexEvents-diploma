import { Router } from 'express';
import multer from 'multer';
import path from 'path';
import fs from 'fs';
import uploadController from '../controllers/upload.controller.js';
import { authMiddleware } from '../middleware/auth.middleware.js';

const router = Router();

// Configure multer for LOCAL DISK storage
const storage = multer.diskStorage({
    destination: function (req, file, cb) {
        const uploadDir = path.join(process.cwd(), 'public/uploads');
        // Ensure directory exists
        if (!fs.existsSync(uploadDir)) {
            fs.mkdirSync(uploadDir, { recursive: true });
        }
        cb(null, uploadDir);
    },
    filename: function (req, file, cb) {
        const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
        const ext = path.extname(file.originalname) || '.jpg';
        cb(null, 'file-' + uniqueSuffix + ext);
    }
});

const upload = multer({
    storage: storage,
    limits: {
        fileSize: 10 * 1024 * 1024, // 10MB limit
    },
});

// POST /api/upload
router.post('/', authMiddleware, upload.single('file'), uploadController.uploadFile);

export default router;
