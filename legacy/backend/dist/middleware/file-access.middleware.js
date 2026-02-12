import logger from '../utils/logger.js';
/**
 * Middleware для проверки прав доступа к файлам
 * Разрешает ЧТЕНИЕ файлов (они уже защищены на upload уровне)
 * Проверяет только попытки обхода path traversal
 */
export const fileAccessMiddleware = (req, res, next) => {
    try {
        // Для GET запросов (чтение) - разрешаем доступ всем (файлы уже защищены на upload)
        if (req.method === 'GET') {
            // Простая проверка на path traversal попытки
            if (req.path.includes('..') || req.path.includes('//')) {
                logger.warn(`[FileAccess] 🚫 Попытка Path Traversal обнаружена:`, {
                    path: req.path,
                    ip: req.ip,
                    userAgent: req.get('user-agent'),
                    timestamp: new Date().toISOString(),
                });
                return res.status(400).json({
                    success: false,
                    message: 'Invalid file path'
                });
            }
            logger.info(`[FileAccess] ✅ GET доступ разрешен:`, {
                path: req.path,
                ip: req.ip,
            });
            return next();
        }
        // Для других методов (POST, PUT, DELETE) - требуем авторизацию
        const authenticatedUserId = req.user?.userId;
        if (!authenticatedUserId) {
            logger.warn(`[FileAccess] 🚫 Неавторизованная попытка ${req.method}:`, {
                ip: req.ip,
                path: req.path,
                timestamp: new Date().toISOString(),
            });
            return res.status(401).json({
                success: false,
                message: 'Unauthorized. Please log in.'
            });
        }
        // Получаем userId из параметров URL: /uploads/{bucket}/{userId}/{filename}
        const parts = req.path.split('/').filter(Boolean);
        // Если меньше 2 частей (bucket/userId), блокируем
        if (parts.length < 2) {
            logger.warn(`[FileAccess] 🚫 Подозрительный запрос с неверной структурой пути:`, {
                authenticatedUserId,
                path: req.path,
                ip: req.ip,
                timestamp: new Date().toISOString(),
            });
            return res.status(400).json({
                success: false,
                message: 'Invalid file path'
            });
        }
        const [bucket, fileUserId, ...filenameParts] = parts;
        const filename = filenameParts.join('/');
        // Валидируем что fileUserId не пуст
        if (!fileUserId || fileUserId === 'undefined' || fileUserId === 'null') {
            logger.warn(`[FileAccess] 🚫 Попытка обхода: пустой userId:`, {
                authenticatedUserId,
                bucket,
                path: req.path,
                ip: req.ip,
                timestamp: new Date().toISOString(),
            });
            return res.status(403).json({
                success: false,
                message: 'Access denied'
            });
        }
        // ГЛАВНАЯ ПРОВЕРКА: блокируем доступ к чужим файлам при POST/PUT/DELETE
        if (fileUserId !== authenticatedUserId) {
            logger.error(`[FileAccess] 🚫🚫🚫 НЕСАНКЦИОНИРОВАННЫЙ ДОСТУП К ЧУЖИМ ФАЙЛАМ:`, {
                authenticatedUserId,
                attemptedFileUserId: fileUserId,
                bucket,
                filename,
                ip: req.ip,
                userAgent: req.get('user-agent'),
                timestamp: new Date().toISOString(),
            });
            // Блокируем с 403 Forbidden
            return res.status(403).json({
                success: false,
                message: 'Access denied. You can only access your own files.'
            });
        }
        // Валидируем что userId не содержит опасных символов
        if (!/^[a-zA-Z0-9\-_]+$/.test(fileUserId)) {
            logger.warn(`[FileAccess] 🚫 Подозрительный userId (опасные символы):`, {
                authenticatedUserId,
                attemptedFileUserId: fileUserId,
                ip: req.ip,
                timestamp: new Date().toISOString(),
            });
            return res.status(400).json({
                success: false,
                message: 'Invalid file path'
            });
        }
        // Все проверки прошли - разрешаем доступ
        logger.info(`[FileAccess] ✅ Санкционированный доступ:`, {
            userId: authenticatedUserId,
            bucket,
            filename,
            ip: req.ip,
        });
        next();
    }
    catch (error) {
        logger.error(`[FileAccess] ❌ Критическая ошибка в middleware:`, {
            error: error.message,
            stack: error.stack,
            timestamp: new Date().toISOString(),
        });
        // В случае ошибки - блокируем доступ из соображений безопасности
        return res.status(500).json({
            success: false,
            message: 'Access check failed'
        });
    }
};
//# sourceMappingURL=file-access.middleware.js.map