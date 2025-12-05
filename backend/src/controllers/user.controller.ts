import type { Request, Response } from 'express';
import type { AuthRequest } from '../middleware/auth.middleware.js';
import * as userService from '../services/user.service.js';
import logger from '../utils/logger.js';

/**
 * POST /api/users
 * Создание нового пользователя (регистрация)
 */
export async function createUser(req: Request, res: Response): Promise<void> {
  try {
    // 1. Получаем данные из тела запроса
    const { firebaseUid, email, displayName, photoUrl } = req.body;

    // 2. Валидация обязательных полей
    if (!firebaseUid || !email) {
      res.status(400).json({
        success: false,
        message: 'firebaseUid and email are required',
      });
      return;
    }

    // 3. Создаём пользователя через сервис
    const user = await userService.createUser({
      firebaseUid,
      email,
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
    if (error.message === 'User with this email already exists') {
      res.status(409).json({
        success: false,
        message: error.message,
      });
      return;
    }

    logger.error('Error creating user:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to create user',
    });
  }
}

/**
 * GET /api/users/me
 * Получение профиля текущего пользователя
 */
export async function getCurrentUser(req: AuthRequest, res: Response): Promise<void> {
  try {
    const userId = req.user?.userId; // Используем UUID из БД

    if (!userId) {
      res.status(401).json({
        success: false,
        message: 'Unauthorized: User ID not found',
      });
      return;
    }

    const user = await userService.getUserById(userId);

    if (!user) {
      res.status(404).json({
        success: false,
        message: 'User not found',
      });
      return;
    }

    res.status(200).json({
      success: true,
      data: user,
    });
  } catch (error) {
    logger.error('Error getting current user:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to get user',
    });
  }
}

/**
 * PUT /api/users/me
 * Обновление профиля пользователя
 */
export async function updateProfile(req: AuthRequest, res: Response): Promise<void> {
  try {
    const userId = req.user?.userId; // Используем UUID из БД

    if (!userId) {
      res.status(401).json({
        success: false,
        message: 'Unauthorized: User ID not found',
      });
      return;
    }

    const { displayName, photoUrl, bio, age, gender, interests, socialLinks, isOnboardingCompleted } = req.body;

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
    logger.error('Error updating profile:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to update profile',
    });
  }
}

/**
 * PUT /api/users/me/location
 * Обновление геолокации пользователя
 */
export async function updateLocation(req: AuthRequest, res: Response): Promise<void> {
  try {
    const userId = req.user?.userId; // Используем UUID из БД

    if (!userId) {
      res.status(401).json({
        success: false,
        message: 'Unauthorized: User ID not found',
      });
      return;
    }

    const { latitude, longitude } = req.body;

    // Валидация координат
    if (
      typeof latitude !== 'number' ||
      typeof longitude !== 'number' ||
      latitude < -90 ||
      latitude > 90 ||
      longitude < -180 ||
      longitude > 180
    ) {
      res.status(400).json({
        success: false,
        message: 'Invalid coordinates. Latitude must be between -90 and 90, longitude between -180 and 180',
      });
      return;
    }

    await userService.updateUserLocation(userId, latitude, longitude);

    logger.info(`User location updated: ${userId}`);
    res.status(200).json({
      success: true,
      message: 'Location updated successfully',
    });
  } catch (error) {
    logger.error('Error updating location:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to update location',
    });
  }
}

