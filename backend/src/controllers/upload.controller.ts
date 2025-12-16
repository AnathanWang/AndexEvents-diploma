import type { Response } from 'express';
import type { AuthRequest } from '../middleware/auth.middleware.js';
import logger from '../utils/logger.js';
import prisma from '../utils/prisma.js';

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
            
            // Construct public URL: /uploads/{bucket}/{userId}/{filename}
            const protocol = req.protocol;
            const host = req.get('host');
            const publicUrl = `${protocol}://${host}/uploads/${bucket}/${userId}/${fileName}`;

            // Логируем загрузку в деталях
            logger.info(`[Upload] ✅ Успешная загрузка:`, {
                fileName,
                fileSize: `${(fileSize / 1024 / 1024).toFixed(2)}MB`,
                bucket,
                userId,
                mimeType: file.mimetype,
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
