import type { Response } from "express";
import type { AuthRequest } from "../middleware/auth.middleware.js";
import * as userService from "../services/user.service.js";
import logger from "../utils/logger.js";

/**
 * POST /api/users
 * Создание нового пользователя (регистрация)
 */
export async function createUser(req: AuthRequest, res: Response): Promise<void> {
  try {
    // 1. Supabase JWT обязателен: uid/email берём только из токена
    const authUid = req.user?.uid;
    const authEmail = req.user?.email;

    // Дополнительные поля можно прислать из клиента
    const { displayName, photoUrl } = req.body;

    logger.info(
      `[CreateUser] Request received for uid: ${authUid}, email: ${authEmail}`,
    );

    // 2. Валидация обязательных полей
    if (!authUid || !authEmail) {
      logger.warn("[CreateUser] Missing required fields");
      res.status(401).json({
        success: false,
        message: "Unauthorized: valid token with uid/email is required",
      });
      return;
    }

    // 3. Создаём пользователя через сервис
    logger.info(
      `[CreateUser] Calling userService.createUser with: ${JSON.stringify({ supabaseUid: authUid, email: authEmail, displayName })}`,
    );
    const user = await userService.createUser({
      supabaseUid: authUid,
      email: authEmail,
      displayName: displayName || null,
      photoUrl: photoUrl || null,
    });

    // 4. Возвращаем успешный ответ
    logger.info(`User created successfully: ${user.id}`);
    res.status(201).json({
      success: true,
      data: user,
    });
  } catch (error: any) {
    // Обработка ошибки дублирования email
    if (error.message === "User with this email already exists") {
      res.status(409).json({
        success: false,
        message: error.message,
      });
      return;
    }

    logger.error("Error creating user:", error);
    res.status(500).json({
      success: false,
      message: "Failed to create user",
    });
  }
}

/**
 * GET /api/users/me
 * Получение профиля текущего пользователя
 */
export async function getCurrentUser(
  req: AuthRequest,
  res: Response,
): Promise<void> {
  try {
    const userId = req.user?.userId; // Используем UUID из БД

    if (!userId) {
      res.status(401).json({
        success: false,
        message: "Unauthorized: User ID not found",
      });
      return;
    }

    const user = await userService.getUserById(userId);

    if (!user) {
      res.status(404).json({
        success: false,
        message: "User not found",
      });
      return;
    }

    res.status(200).json({
      success: true,
      data: user,
    });
  } catch (error) {
    logger.error("Error getting current user:", error);
    res.status(500).json({
      success: false,
      message: "Failed to get user",
    });
  }
}

/**
 * PUT /api/users/me
 * Обновление профиля пользователя
 */
export async function updateProfile(
  req: AuthRequest,
  res: Response,
): Promise<void> {
  try {
    const userId = req.user?.userId; // Используем UUID из БД

    if (!userId) {
      res.status(401).json({
        success: false,
        message: "Unauthorized: User ID not found",
      });
      return;
    }

    const {
      displayName,
      photoUrl,
      bio,
      age,
      gender,
      interests,
      socialLinks,
      isOnboardingCompleted,
    } = req.body;

    const updatedUser = await userService.updateUserProfile(userId, {
      displayName,
      photoUrl,
      bio,
      age,
      gender,
      interests,
      socialLinks,
      isOnboardingCompleted,
    });

    logger.info(`User profile updated: ${userId}`);
    res.status(200).json({
      success: true,
      data: updatedUser,
    });
  } catch (error) {
    logger.error("Error updating profile:", error);
    res.status(500).json({
      success: false,
      message: "Failed to update profile",
    });
  }
}

/**
 * PUT /api/users/me/location
 * Обновление геолокации пользователя
 */
export async function updateLocation(
  req: AuthRequest,
  res: Response,
): Promise<void> {
  try {
    const userId = req.user?.userId; // Используем UUID из БД

    if (!userId) {
      res.status(401).json({
        success: false,
        message: "Unauthorized: User ID not found",
      });
      return;
    }

    const { latitude, longitude } = req.body;

    // Валидация координат
    if (
      typeof latitude !== "number" ||
      typeof longitude !== "number" ||
      latitude < -90 ||
      latitude > 90 ||
      longitude < -180 ||
      longitude > 180
    ) {
      res.status(400).json({
        success: false,
        message:
          "Invalid coordinates. Latitude must be between -90 and 90, longitude between -180 and 180",
      });
      return;
    }

    await userService.updateUserLocation(userId, latitude, longitude);

    logger.info(`User location updated: ${userId}`);
    res.status(200).json({
      success: true,
      message: "Location updated successfully",
    });
  } catch (error) {
    logger.error("Error updating location:", error);
    res.status(500).json({
      success: false,
      message: "Failed to update location",
    });
  }
}

/**
 * GET /api/users/matches
 * Получение списка потенциальных матчей для текущего пользователя
 */
export async function getMatches(
  req: AuthRequest,
  res: Response,
): Promise<void> {
  try {
    const userId = req.user?.userId; // Используем UUID из БД

    if (!userId) {
      res.status(401).json({
        success: false,
        message: "Unauthorized: User ID not found",
      });
      return;
    }

    // Получаем параметры запроса
    const latitude = req.query.latitude
      ? parseFloat(req.query.latitude as string)
      : undefined;
    const longitude = req.query.longitude
      ? parseFloat(req.query.longitude as string)
      : undefined;
    const radiusKm = req.query.radiusKm
      ? parseInt(req.query.radiusKm as string)
      : 50;
    const limit = req.query.limit ? parseInt(req.query.limit as string) : 20;

    // Валидация координат, если они предоставлены
    if (latitude !== undefined && longitude !== undefined) {
      if (
        typeof latitude !== "number" ||
        typeof longitude !== "number" ||
        latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180
      ) {
        res.status(400).json({
          success: false,
          message:
            "Invalid coordinates. Latitude must be between -90 and 90, longitude between -180 and 180",
        });
        return;
      }
    }

    logger.info(
      `[GetMatches] Fetching matches for user ${userId} with params: lat=${latitude}, lon=${longitude}, radiusKm=${radiusKm}, limit=${limit}`,
    );

    const matches = await userService.getMatchesForUser(
      userId,
      latitude,
      longitude,
      radiusKm,
      limit,
    );

    logger.info(
      `[GetMatches] Found ${matches.length} matches for user ${userId}`,
    );

    res.status(200).json({
      success: true,
      data: matches,
    });
  } catch (error) {
    logger.error("Error fetching matches:", error);
    res.status(500).json({
      success: false,
      message: "Failed to fetch matches",
    });
  }
}
