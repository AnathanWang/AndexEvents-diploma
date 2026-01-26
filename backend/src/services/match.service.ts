import { PrismaClient } from "../generated/prisma/index.js";
import type { Match, MatchAction } from "../generated/prisma/index.js";
import logger from "../utils/logger.js";

const prisma = new PrismaClient();

export const createOrUpdateMatch = async (
  userAId: string,
  userBId: string,
  action: MatchAction,
): Promise<Match> => {
  logger.info(
    `[createOrUpdateMatch] Creating/updating match between ${userAId} and ${userBId} with action ${action}`,
  );

  try {
    // Проверяем, существует ли уже матч между этими пользователями
    let match = await prisma.match.findUnique({
      where: {
        userAId_userBId: {
          userAId,
          userBId,
        },
      },
    });

    if (!match) {
      // Если матча нет, проверяем в обратном порядке (userB -> userA)
      match = await prisma.match.findUnique({
        where: {
          userAId_userBId: {
            userAId: userBId,
            userBId: userAId,
          },
        },
      });

      if (!match) {
        // Создаём новый матч
        logger.info(
          `[createOrUpdateMatch] Creating new match between ${userAId} and ${userBId}`,
        );
        match = await prisma.match.create({
          data: {
            userAId,
            userBId,
            userAAction: action,
            isMutual: false,
          },
        });
        return match;
      } else {
        // Обновляем существующий матч (обратный порядок)
        logger.info(
          `[createOrUpdateMatch] Updating existing reverse match between ${userBId} and ${userAId}`,
        );

        // Проверяем, есть ли взаимный лайк
        const isMutual = _isMutualLike(match.userBAction, action);

        match = await prisma.match.update({
          where: {
            id: match.id,
          },
          data: {
            userBAction: action,
            isMutual,
            matchedAt: isMutual ? new Date() : null,
          },
        });

        return match;
      }
    } else {
      // Обновляем существующий матч
      logger.info(
        `[createOrUpdateMatch] Updating existing match between ${userAId} and ${userBId}`,
      );

      // Проверяем, есть ли взаимный лайк
      const isMutual = _isMutualLike(match.userBAction, action);

      match = await prisma.match.update({
        where: {
          id: match.id,
        },
        data: {
          userAAction: action,
          isMutual,
          matchedAt: isMutual ? new Date() : null,
        },
      });

      return match;
    }
  } catch (error) {
    logger.error(
      `[createOrUpdateMatch] Error creating/updating match between ${userAId} and ${userBId}:`,
      error,
    );
    throw error;
  }
};

/**
 * Проверить, есть ли взаимный лайк
 */
function _isMutualLike(action1: MatchAction | null, action2: MatchAction): boolean {
  if (!action1) {
    return false;
  }
  return (action1 === "LIKE" || action1 === "SUPER_LIKE") && (action2 === "LIKE" || action2 === "SUPER_LIKE");
}

/**
 * Получить все матчи пользователя
 */
export const getUserMatches = async (userId: string): Promise<Match[]> => {
  logger.info(`[getUserMatches] Fetching matches for user ${userId}`);

  try {
    const matches = await prisma.match.findMany({
      where: {
        OR: [
          {
            userAId: userId,
          },
          {
            userBId: userId,
          },
        ],
        isMutual: true,
      },
      include: {
        userA: true,
        userB: true,
      },
    });

    logger.info(`[getUserMatches] Found ${matches.length} matches for user ${userId}`);
    return matches;
  } catch (error) {
    logger.error(`[getUserMatches] Error fetching matches for user ${userId}:`, error);
    throw error;
  }
};

/**
 * Получить истину действий пользователя
 */
export const getUserActions = async (
  userId: string,
  limit: number = 50,
): Promise<Match[]> => {
  logger.info(`[getUserActions] Fetching actions for user ${userId}`);

  try {
    const actions = await prisma.match.findMany({
      where: {
        OR: [
          {
            userAId: userId,
          },
          {
            userBId: userId,
          },
        ],
      },
      orderBy: {
        createdAt: "desc",
      },
      take: limit,
      include: {
        userA: true,
        userB: true,
      },
    });

    logger.info(`[getUserActions] Found ${actions.length} actions for user ${userId}`);
    return actions;
  } catch (error) {
    logger.error(`[getUserActions] Error fetching actions for user ${userId}:`, error);
    throw error;
  }
};
