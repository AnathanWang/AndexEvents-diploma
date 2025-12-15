import { Router } from 'express';
import multer from 'multer';
import path from 'node:path';
import fs from 'node:fs';
import crypto from 'node:crypto';
import uploadController from '../controllers/upload.controller.js';
import { authMiddleware } from '../middleware/auth.middleware.js';
import logger from '../utils/logger.js';

const router = Router();

// Поддерживаемые бакеты
const BUCKETS = {
    AVATARS: 'avatars',
    EVENTS: 'events'
};

// Максимальные размеры файлов (в байтах)
const MAX_FILE_SIZES = {
    [BUCKETS.AVATARS]: 5 * 1024 * 1024,    // 5MB для аватаров
    [BUCKETS.EVENTS]: 10 * 1024 * 1024,    // 10MB для событий
};

// Разрешённые MIME типы (включая альтернативные для совместимости)
const ALLOWED_MIME_TYPES = new Set([
    'image/jpeg',
    'image/jpg',
    'image/png',
    'image/webp',
    'image/gif',
    'image/x-png', // iOS иногда отправляет так
    'application/octet-stream', // fallback для iOS
]);

// Магические числа для валидации (file signatures)
const FILE_SIGNATURES = {
    jpeg: Buffer.from([0xFF, 0xD8, 0xFF]),
    png: Buffer.from([0x89, 0x50, 0x4E, 0x47]),
    gif: Buffer.from([0x47, 0x49, 0x46]),
    webp: Buffer.from([0x52, 0x49, 0x46, 0x46]) // RIFF для WebP
};

/**
 * Валидирует файл по его магическим числам
 */
function validateFileSignature(buffer: Buffer, mimeType: string): boolean {
    if (mimeType === 'image/jpeg') {
        return buffer.subarray(0, 3).equals(FILE_SIGNATURES.jpeg);
    }
    if (mimeType === 'image/png') {
        return buffer.subarray(0, 4).equals(FILE_SIGNATURES.png);
    }
    if (mimeType === 'image/gif') {
        return buffer.subarray(0, 3).equals(FILE_SIGNATURES.gif);
    }
    if (mimeType === 'image/webp') {
        // WebP: RIFF...WEBP
        return buffer.subarray(0, 4).equals(FILE_SIGNATURES.webp) &&
               buffer.subarray(8, 12).toString('utf8') === 'WEBP';
    }
    return false;
}

/**
 * Санитизирует имя файла (предотвращает Path Traversal)
 */
function sanitizeFilename(filename: string): string {
    // Убираем опасные символы и path traversal попытки
    return filename
        .replaceAll('..', '')           // Удаляем ..
        .replaceAll(/[/\\]/g, '')       // Удаляем слэши
        .replaceAll(/[^\w\s.-]/g, '')   // Оставляем только буквы, цифры, точку, дефис, подчёркивание
        .trim();
}

// Configure multer for LOCAL DISK storage с системой папок по пользователям
const storage = multer.diskStorage({
    destination: function (req, file, cb) {
        try {
            // Получаем бакет из query параметра или используем default
            const bucket = (req.query.bucket as string) || BUCKETS.EVENTS;
            const userId = (req as any).user?.userId;
            
            logger.info(`[Upload] destination callback:`, {
                bucket,
                userId,
                userObj: (req as any).user,
                authHeader: req.headers.authorization ? 'present' : 'missing',
            }); // Используем userId вместо id
            
            // Валидируем бакет
            if (!Object.values(BUCKETS).includes(bucket)) {
                logger.error(`[Upload] Неправильное имя бакета: ${bucket}`);
                return cb(new Error('Invalid bucket name'), '');
            }

            if (!userId) {
                logger.error('[Upload] ID пользователя не найден');
                return cb(new Error('User ID is required'), '');
            }

            // Санитизируем userId (защита от path traversal)
            const sanitizedUserId = sanitizeFilename(userId);
            if (sanitizedUserId !== userId) {
                logger.warn(`[Upload] UserID санитизирован: ${userId} -> ${sanitizedUserId}`);
            }

            // Структура: public/uploads/{bucket}/{userId}/
            const uploadDir = path.join(process.cwd(), `public/uploads/${bucket}/${sanitizedUserId}`);
            
            // Создаем базовую директорию если её нет
            const baseUploadDir = path.join(process.cwd(), 'public/uploads');
            if (!fs.existsSync(baseUploadDir)) {
                fs.mkdirSync(baseUploadDir, { recursive: true });
            }
            
            // Проверяем, что путь остаётся в пределах public/uploads
            const realUploadDir = fs.realpathSync(baseUploadDir);
            const realTargetDir = fs.realpathSync(uploadDir);
            
            if (!realTargetDir.startsWith(realUploadDir)) {
                logger.error(`[Upload] Попытка Path Traversal: ${realTargetDir}`);
                return cb(new Error('Invalid upload directory'), '');
            }
            
            // Создаем директорию если её нет
            if (!fs.existsSync(uploadDir)) {
                fs.mkdirSync(uploadDir, { recursive: true });
            }
            
            logger.info(`[Upload] Бакет: ${bucket}, Пользователь: ${sanitizedUserId}, Директория создана`);
            cb(null, uploadDir);
        } catch (error: any) {
            logger.error(`[Upload] Ошибка в destination: ${error.message}`);
            cb(error, '');
        }
    },
    filename: function (req, file, cb) {
        try {
            // Генерируем безопасное имя: timestamp-random.ext
            const uniqueSuffix = Date.now() + '-' + crypto.randomBytes(4).toString('hex');
            const ext = path.extname(file.originalname).toLowerCase() || '.jpg';
            const filename = `${uniqueSuffix}${ext}`;
            
            logger.info(`[Upload] Сгенерировано имя файла: ${filename}`);
            cb(null, filename);
        } catch (error: any) {
            logger.error(`[Upload] Ошибка в filename: ${error.message}`);
            cb(error, '');
        }
    }
});

const upload = multer({
    storage: storage,
    limits: {
        fileSize: 10 * 1024 * 1024, // 10MB максимум
    },
    fileFilter: (req, file, cb) => {
        try {
            // 1. Валидируем MIME type - более гибкий подход
            const mimeType = file.mimetype.toLowerCase().trim();
            
            // Проверяем известные image типы
            const isValidImage = mimeType.startsWith('image/') || 
                                 mimeType === 'application/octet-stream'; // fallback для iOS
            
            if (!isValidImage) {
                logger.warn(`[Upload] Неправильный MIME type: ${mimeType}`);
                return cb(new Error('Invalid file type. Only images are allowed'));
            }

            // 2. Проверяем расширение файла
            const ext = path.extname(file.originalname).toLowerCase();
            const validExtensions = ['.jpg', '.jpeg', '.png', '.gif', '.webp'];
            if (!validExtensions.includes(ext)) {
                logger.warn(`[Upload] Неправильное расширение файла: ${ext}`);
                return cb(new Error('Invalid file extension. Only jpg, png, gif, webp are allowed'));
            }

            // 3. Санитизируем имя файла
            const sanitizedName = sanitizeFilename(file.originalname);
            if (sanitizedName !== file.originalname) {
                logger.warn(`[Upload] Имя файла санитизировано: ${file.originalname} -> ${sanitizedName}`);
                file.originalname = sanitizedName;
            }

            cb(null, true);
        } catch (error: any) {
            logger.error(`[Upload] Ошибка в fileFilter: ${error.message}`);
            cb(error);
        }
    }
});

// POST /api/upload?bucket=avatars или /api/upload?bucket=events
// Структура URL будет: /uploads/{bucket}/{userId}/timestamp.jpg
router.post('/', authMiddleware, upload.single('file'), uploadController.uploadFile);

export default router;
