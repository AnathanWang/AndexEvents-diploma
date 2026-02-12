import type { Request, Response } from 'express';
import type { AuthRequest } from '../middleware/auth.middleware.js';
/**
 * POST /api/users
 * Создание нового пользователя (регистрация)
 */
export declare function createUser(req: Request, res: Response): Promise<void>;
/**
 * GET /api/users/me
 * Получение профиля текущего пользователя
 */
export declare function getCurrentUser(req: AuthRequest, res: Response): Promise<void>;
/**
 * PUT /api/users/me
 * Обновление профиля пользователя
 */
export declare function updateProfile(req: AuthRequest, res: Response): Promise<void>;
/**
 * PUT /api/users/me/location
 * Обновление геолокации пользователя
 */
export declare function updateLocation(req: AuthRequest, res: Response): Promise<void>;
//# sourceMappingURL=user.controller.d.ts.map