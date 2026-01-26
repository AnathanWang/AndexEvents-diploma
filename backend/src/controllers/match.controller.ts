import type { Request, Response } from "express";
import type { AuthRequest } from "../middleware/auth.middleware.js";
import * as matchService from "../services/match.service.js";
import logger from "../utils/logger.js";

type MatchActionString = "LIKE" | "DISLIKE" | "SUPER_LIKE";

function isMatchAction(value: unknown): value is MatchActionString {
  return value === "LIKE" || value === "DISLIKE" || value === "SUPER_LIKE";
}

/**
 * GET /api/matches
 * Получить список взаимных матчей текущего пользователя
 * Возвращает массив пользователей ("другая сторона" матча), чтобы клиент мог использовать существующую UserModel.
 */
export async function getMyMutualMatches(
  req: AuthRequest,
  res: Response,
): Promise<void> {
  try {
    const userId = req.user?.userId;

    if (!userId) {
      res.status(401).json({
        success: false,
        message: "Unauthorized: User ID not found",
      });
      return;
    }

    const matches = await matchService.getUserMatches(userId);

    const users = matches
      .map((match: any) => {
        if (match.userAId === userId) {
          return match.userB;
        }
        return match.userA;
      })
      .filter(Boolean);

    res.status(200).json({
      success: true,
      data: users,
    });
  } catch (error) {
    logger.error("Error fetching mutual matches:", error);
    res.status(500).json({
      success: false,
      message: "Failed to fetch mutual matches",
    });
  }
}

/**
 * GET /api/matches/actions?action=LIKE|DISLIKE|SUPER_LIKE&limit=50
 * Получить пользователей, по которым текущий пользователь совершал действие.
 */
export async function getMyActions(
  req: AuthRequest,
  res: Response,
): Promise<void> {
  try {
    const userId = req.user?.userId;

    if (!userId) {
      res.status(401).json({
        success: false,
        message: "Unauthorized: User ID not found",
      });
      return;
    }

    const actionRaw = req.query.action as unknown;
    if (!isMatchAction(actionRaw)) {
      res.status(400).json({
        success: false,
        message: "Query param 'action' must be LIKE, DISLIKE, or SUPER_LIKE",
      });
      return;
    }

    const limitRaw = req.query.limit as string | undefined;
    const limit = limitRaw ? Math.max(1, Math.min(200, parseInt(limitRaw, 10))) : 50;

    const actions = await matchService.getUserActions(userId, limit);

    const users = actions
      .map((match: any) => {
        const isUserA = match.userAId === userId;
        const myAction = isUserA ? match.userAAction : match.userBAction;

        if (myAction !== actionRaw) {
          return null;
        }

        return isUserA ? match.userB : match.userA;
      })
      .filter(Boolean);

    res.status(200).json({
      success: true,
      data: users,
    });
  } catch (error) {
    logger.error("Error fetching match actions:", error);
    res.status(500).json({
      success: false,
      message: "Failed to fetch match actions",
    });
  }
}

/**
 * POST /api/matches/like
 * Отправить лайк пользователю
 */
export async function sendLike(
  req: AuthRequest,
  res: Response,
): Promise<void> {
  try {
    const userId = req.user?.userId;

    if (!userId) {
      res.status(401).json({
        success: false,
        message: "Unauthorized: User ID not found",
      });
      return;
    }

    const { targetUserId } = req.body;

    if (!targetUserId) {
      res.status(400).json({
        success: false,
        message: "targetUserId is required",
      });
      return;
    }

    if (userId === targetUserId) {
      res.status(400).json({
        success: false,
        message: "Cannot like yourself",
      });
      return;
    }

    logger.info(`[SendLike] User ${userId} likes user ${targetUserId}`);

    const result = await matchService.createOrUpdateMatch(
      userId,
      targetUserId,
      "LIKE",
    );

    res.status(200).json({
      success: true,
      data: result,
      message: result.isMutual ? "It's a match! 🎉" : "Like sent!",
    });
  } catch (error) {
    logger.error("Error sending like:", error);
    res.status(500).json({
      success: false,
      message: "Failed to send like",
    });
  }
}

/**
 * POST /api/matches/dislike
 * Отправить дизлайк пользователю
 */
export async function sendDislike(
  req: AuthRequest,
  res: Response,
): Promise<void> {
  try {
    const userId = req.user?.userId;

    if (!userId) {
      res.status(401).json({
        success: false,
        message: "Unauthorized: User ID not found",
      });
      return;
    }

    const { targetUserId } = req.body;

    if (!targetUserId) {
      res.status(400).json({
        success: false,
        message: "targetUserId is required",
      });
      return;
    }

    if (userId === targetUserId) {
      res.status(400).json({
        success: false,
        message: "Cannot dislike yourself",
      });
      return;
    }

    logger.info(`[SendDislike] User ${userId} dislikes user ${targetUserId}`);

    const result = await matchService.createOrUpdateMatch(
      userId,
      targetUserId,
      "DISLIKE",
    );

    res.status(200).json({
      success: true,
      data: result,
      message: "Dislike recorded",
    });
  } catch (error) {
    logger.error("Error sending dislike:", error);
    res.status(500).json({
      success: false,
      message: "Failed to send dislike",
    });
  }
}

/**
 * POST /api/matches/super-like
 * Отправить супер-лайк пользователю
 */
export async function sendSuperLike(
  req: AuthRequest,
  res: Response,
): Promise<void> {
  try {
    const userId = req.user?.userId;

    if (!userId) {
      res.status(401).json({
        success: false,
        message: "Unauthorized: User ID not found",
      });
      return;
    }

    const { targetUserId } = req.body;

    if (!targetUserId) {
      res.status(400).json({
        success: false,
        message: "targetUserId is required",
      });
      return;
    }

    if (userId === targetUserId) {
      res.status(400).json({
        success: false,
        message: "Cannot super like yourself",
      });
      return;
    }

    logger.info(
      `[SendSuperLike] User ${userId} super likes user ${targetUserId}`,
    );

    const result = await matchService.createOrUpdateMatch(
      userId,
      targetUserId,
      "SUPER_LIKE",
    );

    res.status(200).json({
      success: true,
      data: result,
      message: result.isMutual ? "It's a match! 🎉" : "Super like sent!",
    });
  } catch (error) {
    logger.error("Error sending super like:", error);
    res.status(500).json({
      success: false,
      message: "Failed to send super like",
    });
  }
}
