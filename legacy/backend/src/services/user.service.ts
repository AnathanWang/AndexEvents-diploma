import { PrismaClient } from "../generated/prisma/index.js";
import type { User } from "../generated/prisma/index.js";
import logger from "../utils/logger.js";
import { createUserStorageFolders } from "../utils/user-storage.js";

const prisma = new PrismaClient();

interface CreateUserData {
  supabaseUid: string;
  email: string;
  displayName?: string;
  photoUrl?: string;
}

interface UpdateProfileData {
  displayName?: string;
  bio?: string;
  interests?: string[];
  socialLinks?: Record<string, string>;
  age?: number;
  gender?: string;
  photoUrl?: string;
  isOnboardingCompleted?: boolean;
}

export const createUser = async (data: CreateUserData): Promise<User> => {
  try {
    logger.info(`Creating user with UID: ${data.supabaseUid}`);
    const existingUser = await prisma.user.findUnique({
      where: { email: data.email },
    });
    if (existingUser) {
      logger.info(`User already exists with email: ${data.email}`);
      // Создаём папки для существующего пользователя (если их ещё нет)
      createUserStorageFolders(existingUser.id);

      // Если пользователь существует, но у него нет supabaseUid (например, старая запись), обновим его
      if (!existingUser.supabaseUid) {
        logger.info(
          `Updating existing user ${existingUser.id} with supabaseUid: ${data.supabaseUid}`,
        );
        return await prisma.user.update({
          where: { id: existingUser.id },
          data: { supabaseUid: data.supabaseUid },
        });
      }
      // Если supabaseUid уже есть и совпадает - вернем пользователя
      if (existingUser.supabaseUid === data.supabaseUid) {
        return existingUser;
      }
      // Если supabaseUid отличается - это конфликт
      throw new Error("User with this email already exists");
    }
    const newUser = await prisma.user.create({
      data: {
        supabaseUid: data.supabaseUid,
        email: data.email,
        displayName: data.displayName || "",
        photoUrl: data.photoUrl || "",
      },
    });
    logger.info(`User created with UID: ${data.supabaseUid}`);

    // Создаём папки для хранения файлов пользователя
    createUserStorageFolders(newUser.id);

    return newUser;
  } catch (error) {
    logger.error(`Error creating user with UID: ${data.supabaseUid}`, error);
    throw error;
  }
};

export const getUserBySupabaseUid = async (
  supabaseUid: string,
): Promise<User | null> => {
  logger.info(`Fetching user with UID: ${supabaseUid}`);
  try {
    const user = await prisma.user.findUnique({ where: { supabaseUid } });
    if (user) {
      logger.info(`User found with UID: ${supabaseUid}`);
    } else {
      logger.warn(`No user found with UID: ${supabaseUid}`);
    }
    return user;
  } catch (error) {
    logger.error(`Error fetching user with UID: ${supabaseUid}`, error);
    throw error;
  }
};

export const getUserById = async (userId: string): Promise<User | null> => {
  logger.info(`Fetching user with ID: ${userId}`);
  try {
    const user = await prisma.user.findUnique({ where: { id: userId } });
    if (user) {
      logger.info(`User found with ID: ${userId}`);
    } else {
      logger.warn(`No user found with ID: ${userId}`);
    }
    return user;
  } catch (error) {
    logger.error(`Error fetching user with ID: ${userId}`, error);
    throw error;
  }
};

export const updateUserProfile = async (
  userId: string,
  data: UpdateProfileData,
): Promise<User> => {
  logger.info(`Updating profile for user ID: ${userId}`);
  try {
    const user = await prisma.user.update({
      where: { id: userId },
      data: { ...data },
    });
    return user;
  } catch (error) {
    logger.error(`Error updating profile for user ID: ${userId}`, error);
    throw error;
  }
};

export const updateUserLocation = async (
  userId: string,
  latitude: number,
  longitude: number,
): Promise<void> => {
  logger.info(`Updating location for user ID: ${userId}`);
  try {
    await prisma.user.update({
      where: { id: userId },
      data: {
        lastLatitude: latitude,
        lastLongitude: longitude,
        lastLocationUpdate: new Date(),
      },
    });
    logger.info(`Location updated for user ID: ${userId}`);
  } catch (error) {
    logger.error(`Error updating location for user ID: ${userId}`, error);
    throw error;
  }
};

export const getMatchesForUser = async (
  userId: string,
  latitude?: number,
  longitude?: number,
  radiusKm: number = 50,
  limit: number = 20,
): Promise<User[]> => {
  logger.info(`Fetching matches for user ID: ${userId}`);
  try {
    // Получаем текущего пользователя для получения его фильтров
    const currentUser = await prisma.user.findUnique({
      where: { id: userId },
    });

    if (!currentUser) {
      logger.warn(`User not found: ${userId}`);
      return [];
    }

    // Используем переданные координаты или последние известные координаты пользователя
    const userLat = latitude ?? currentUser.lastLatitude;
    const userLon = longitude ?? currentUser.lastLongitude;

    // Если координаты не доступны, возвращаем пустой список
    if (!userLat || !userLon) {
      logger.warn(`No location available for user ${userId}`);
      return [];
    }

    // Вычисляем границы поиска (приближённо)
    const radiusMeters = radiusKm * 1000;
    const earthRadiusKm = 6371;
    const latChange = (radiusKm / earthRadiusKm) * (180 / Math.PI);
    const lonChange =
      (radiusKm / (earthRadiusKm * Math.cos((userLat * Math.PI) / 180))) *
      (180 / Math.PI);

    const minLat = userLat - latChange;
    const maxLat = userLat + latChange;
    const minLon = userLon - lonChange;
    const maxLon = userLon + lonChange;

    logger.info(
      `Search bounds: lat [${minLat}, ${maxLat}], lon [${minLon}, ${maxLon}]`,
    );

    // Получаем пользователей в пределах географической области
    let query: any = {
      where: {
        AND: [
          // Исключаем самого пользователя
          {
            id: {
              not: userId,
            },
          },
          // Исключаем пользователей, которые не завершили онбординг
          {
            isOnboardingCompleted: true,
          },
          // Исключаем невидимые профили
          {
            isProfileVisible: true,
          },
          // Геолокационный фильтр
          {
            lastLatitude: {
              gte: minLat,
              lte: maxLat,
            },
          },
          {
            lastLongitude: {
              gte: minLon,
              lte: maxLon,
            },
          },
        ],
      },
      take: limit,
    };

    // Если установлены возрастные ограничения текущего пользователя, применяем фильтр
    if (currentUser.minAge || currentUser.maxAge) {
      const ageFilter: any = {};
      if (currentUser.minAge) {
        ageFilter.gte = currentUser.minAge;
      }
      if (currentUser.maxAge) {
        ageFilter.lte = currentUser.maxAge;
      }

      query.where.AND.push({
        age: ageFilter,
      });
    }

    const matches = await prisma.user.findMany(query);

    logger.info(`Found ${matches.length} potential matches for user ${userId}`);
    return matches;
  } catch (error) {
    logger.error(`Error fetching matches for user ${userId}:`, error);
    throw error;
  }
};
