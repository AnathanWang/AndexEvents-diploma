import type { Response } from "express";
import type { AuthRequest } from "../middleware/auth.middleware.js";
/**
 * GET /api/friends/status/:userId
 */
export declare function getStatus(req: AuthRequest, res: Response): Promise<void>;
/**
 * POST /api/friends/requests/:userId
 */
export declare function sendRequest(req: AuthRequest, res: Response): Promise<void>;
/**
 * DELETE /api/friends/requests/:userId
 */
export declare function cancelRequest(req: AuthRequest, res: Response): Promise<void>;
/**
 * POST /api/friends/requests/:userId/accept
 * Где :userId — это requester (кто отправил запрос)
 */
export declare function acceptRequest(req: AuthRequest, res: Response): Promise<void>;
/**
 * POST /api/friends/requests/:userId/decline
 * Где :userId — это requester (кто отправил запрос)
 */
export declare function declineRequest(req: AuthRequest, res: Response): Promise<void>;
/**
 * GET /api/friends/requests?type=incoming|outgoing
 */
export declare function listRequests(req: AuthRequest, res: Response): Promise<void>;
/**
 * GET /api/friends
 */
export declare function listFriends(req: AuthRequest, res: Response): Promise<void>;
//# sourceMappingURL=friend.controller.d.ts.map