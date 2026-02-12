import type { Response, NextFunction } from 'express';
import type { AuthRequest } from './auth.middleware.js';
/**
 * Middleware для проверки прав доступа к файлам
 * Разрешает ЧТЕНИЕ файлов (они уже защищены на upload уровне)
 * Проверяет только попытки обхода path traversal
 */
export declare const fileAccessMiddleware: (req: AuthRequest, res: Response, next: NextFunction) => void | Response<any, Record<string, any>>;
//# sourceMappingURL=file-access.middleware.d.ts.map