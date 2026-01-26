import type { Response } from 'express';
import type { AuthRequest } from '../middleware/auth.middleware.js';
import fs from 'node:fs/promises';
import path from 'node:path';
import logger from '../utils/logger.js';
import prisma from '../utils/prisma.js';
import minioService, { BUCKETS, type BucketName } from '../services/minio.service.js';

const BUCKETS = {
    AVATARS: 'avatars',
    EVENTS: 'events'
} as const;

const MAX_FILE_SIZES: Record<string, number> = {
    [BUCKETS.AVATARS]: 5 * 1024 * 1024,    // 5MB
    [BUCKETS.EVENTS]: 10 * 1024 * 1024,    // 10MB
};

const DEFAULT_MAX_FILE_SIZE = 10 * 1024 * 1024; // 10MB

function isValidImageSignature(header: Buffer, mimeType: string): boolean {
    if (mimeType === 'image/jpeg') {
        return header.subarray(0, 3).equals(Buffer.from([0xFF, 0xD8, 0xFF]));
    }
    if (mimeType === 'image/png') {
        return header.subarray(0, 4).equals(Buffer.from([0x89, 0x50, 0x4E, 0x47]));
    }
    if (mimeType === 'image/gif') {
        return header.subarray(0, 3).equals(Buffer.from([0x47, 0x49, 0x46]));
    }
    if (mimeType === 'image/webp') {
        // WebP: RIFF....WEBP
        return (
            header.subarray(0, 4).equals(Buffer.from([0x52, 0x49, 0x46, 0x46])) &&
            header.subarray(8, 12).toString('utf8') === 'WEBP'
        );
    }
    return false;
}

function mimeFromExtension(ext: string): string | null {
    switch (ext) {
        case '.jpg':
        case '.jpeg':
            return 'image/jpeg';
        case '.png':
            return 'image/png';
        case '.gif':
            return 'image/gif';
        case '.webp':
            return 'image/webp';
        default:
            return null;
    }
}

class UploadController {
    async uploadFile(req: AuthRequest, res: Response) {
        const bucket = (req.query.bucket as string) || 'events';
        const userId = (req as any).user?.userId; // Используем userId (UUID из БД) вместо id
        
        if (!userId) {
            logger.error('[Upload] Ошибка: ID пользователя не найден');
            return res.status(401).json({
                success: false,
                message: 'User ID is required',
            });
        }

        // Валидируем имя бакета
        if (!Object.values(BUCKETS).includes(bucket as BucketName)) {
            logger.error(`[Upload] Неверное имя бакета: ${bucket}`);
            return res.status(400).json({
                success: false,
                message: 'Invalid bucket name',
            });
        }

        try {
            const file = (req as any).file;
            if (!file) {
                logger.warn(`[Upload] Попытка загрузки без файла от пользователя ${userId}`);
                return res.status(400).json({
                    success: false,
                    message: 'No file uploaded',
                });
            }

            const fileName = file.filename;
            const fileSize = file.size;

            // Enforce per-bucket size limits (multer limit is global)
            const maxSize = MAX_FILE_SIZES[bucket] ?? DEFAULT_MAX_FILE_SIZE;
            if (typeof fileSize === 'number' && fileSize > maxSize) {
                logger.warn(`[Upload] File too large for bucket ${bucket}: ${fileSize} bytes (max ${maxSize})`, {
                    userId,
                    fileName,
                });
                if (file.path) {
                    await fs.unlink(file.path).catch(() => undefined);
                }
                return res.status(413).json({
                    success: false,
                    message: 'File is too large for this bucket',
                });
            }

            // Validate file signature (magic bytes) after disk write
            // Note: iOS may send application/octet-stream, so we infer from extension.
            const ext = path.extname(file.originalname || fileName).toLowerCase();
            const inferredMime = mimeFromExtension(ext);
            const effectiveMime = (file.mimetype === 'application/octet-stream' && inferredMime)
                ? inferredMime
                : (file.mimetype || '').toLowerCase().trim();

            if (file.path) {
                const header = Buffer.alloc(12);
                const handle = await fs.open(file.path, 'r');
                try {
                    await handle.read(header, 0, header.length, 0);
                } finally {
                    await handle.close();
                }

                if (!isValidImageSignature(header, effectiveMime)) {
                    logger.warn(`[Upload] Invalid file signature`, {
                        userId,
                        bucket,
                        fileName,
                        mimetype: file.mimetype,
                        effectiveMime,
                        ext,
                    });
                    await fs.unlink(file.path).catch(() => undefined);
                    return res.status(400).json({
                        success: false,
                        message: 'Invalid image file',
                    });
                }
            }
            
            // Загружаем файл в MinIO
            // Структура пути: {userId}/{filename}
            const objectName = `${userId}/${fileName}`;
            const publicUrl = await minioService.uploadFile(
                bucket as BucketName,
                objectName,
                file.path,
                effectiveMime || undefined
            );

            // Удаляем временный файл после загрузки в MinIO
            if (file.path) {
                await fs.unlink(file.path).catch((err) => {
                    logger.warn(`[Upload] Не удалось удалить временный файл: ${file.path}`, { error: err.message });
                });
            }

            // Логируем загрузку в деталях
            logger.info(`[Upload] ✅ Успешная загрузка в MinIO:`, {
                fileName,
                fileSize: `${(fileSize / 1024 / 1024).toFixed(2)}MB`,
                bucket,
                userId,
                mimeType: effectiveMime,
                url: publicUrl,
                timestamp: new Date().toISOString(),
                ip: req.ip,
            });

            // Если это аватар - обновляем photoUrl в профиле пользователя
            if (bucket === 'avatars') {
                try {
                    await prisma.user.update({
                        where: { id: userId },
                        data: { photoUrl: publicUrl }
                    });
                    logger.info(`[Upload] ✅ Обновлен photoUrl в профиле:`, { userId, photoUrl: publicUrl });
                } catch (error: any) {
                    logger.warn(`[Upload] ⚠️ Не удалось обновить photoUrl:`, { userId, error: error.message });
                    // Не прерываем процесс если не удалось обновить БД
                }
            }

            return res.json({
                success: true,
                fileUrl: publicUrl,
                file: {
                    name: fileName,
                    size: fileSize,
                    bucket: bucket,
                    userId: userId,
                    uploadedAt: new Date().toISOString(),
                }
            });

        } catch (error: any) {
            logger.error(`[Upload] ❌ Ошибка загрузки:`, {
                bucket,
                userId,
                error: error.message,
                ip: req.ip,
                timestamp: new Date().toISOString(),
            });

            // Не раскрываем подробности ошибки клиенту
            return res.status(500).json({
                success: false,
                message: 'Upload failed. Please try again later.'
            });
        }
    }
}

export default new UploadController();
