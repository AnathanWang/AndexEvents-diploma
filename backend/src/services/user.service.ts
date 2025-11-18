import { PrismaClient } from '../generated/prisma/index.js';
import type { User } from '../generated/prisma/index.js';
import logger from '../utils/logger.js';

const prisma = new PrismaClient();

interface CreateUserData {
  firebaseUid: string;
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
    try{
        logger.info(`Creating user with UID: ${data.firebaseUid}`);
        const existingUser = await prisma.user.findUnique({ where: { email: data.email } });
        if (existingUser) {
            logger.info(`User already exists with email: ${data.email}`);
            throw new Error('User already exists');
        }
        const newUser = await prisma.user.create({
            data: {
                firebaseUid: data.firebaseUid,
                email: data.email,
                displayName: data.displayName || '',
                photoUrl: data.photoUrl || '',
            },
        });
        logger.info(`User created with UID: ${data.firebaseUid}`);
        return newUser;
    } catch (error) {
        logger.error(`Error creating user with UID: ${data.firebaseUid}`, error);
        throw error;
    }
}

export const getUserByFirebaseUid = async (firebaseUid: string): Promise<User | null> => {
    logger.info(`Fetching user with UID: ${firebaseUid}`);
    try {
        const user = await prisma.user.findUnique({ where: { firebaseUid } });
        if (user) {
            logger.info(`User found with UID: ${firebaseUid}`);
        } else {
            logger.warn(`No user found with UID: ${firebaseUid}`);
        }
        return user;
    } catch (error) {
        logger.error(`Error fetching user with UID: ${firebaseUid}`, error);
        throw error;
    }
}

export const updateUserProfile = async (userId: string,data: UpdateProfileData): Promise<User> => {
    logger.info(`Updating profile for user ID: ${userId}`);
    try {
        const user = await prisma.user.update({
            where: { id: userId },
            data: {...data },
        });
        return user;
    } catch (error) {
        logger.error(`Error updating profile for user ID: ${userId}`, error);
        throw error;
    }
}

export const updateUserLocation = async (userId: string, latitude: number, longitude: number): Promise<void> => {
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
}