import type { Response } from "express";
import type { AuthRequest } from "../middleware/auth.middleware.js";
/**
 * GET /api/matches
 * Получить список взаимных матчей текущего пользователя
 * Возвращает массив пользователей ("другая сторона" матча), чтобы клиент мог использовать существующую UserModel.
 */
export declare function getMyMutualMatches(req: AuthRequest, res: Response): Promise<void>;
/**
 * GET /api/matches/actions?action=LIKE|DISLIKE|SUPER_LIKE&limit=50
 * Получить пользователей, по которым текущий пользователь совершал действие.
 */
export declare function getMyActions(req: AuthRequest, res: Response): Promise<void>;
/**
 * POST /api/matches/like
 * Отправить лайк пользователю
 */
export declare function sendLike(req: AuthRequest, res: Response): Promise<void>;
/**
 * POST /api/matches/dislike
 * Отправить дизлайк пользователю
 */
export declare function sendDislike(req: AuthRequest, res: Response): Promise<void>;
/**
 * POST /api/matches/super-like
 * Отправить супер-лайк пользователю
 */
export declare function sendSuperLike(req: AuthRequest, res: Response): Promise<void>;
//# sourceMappingURL=match.controller.d.ts.map