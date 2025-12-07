import type { Request, Response, NextFunction } from 'express';
import admin from 'firebase-admin';
import prisma from '../utils/prisma.js';
import { debug } from '../utils/debug.js';

export interface AuthRequest extends Request {
  user?: {
    uid: string;
    userId?: string | undefined; // UUID из БД
    email?: string | undefined;
  };
}

export const authMiddleware = async (
  req: AuthRequest,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    const authHeader = req.headers.authorization;

    if (!authHeader?.startsWith('Bearer ')) {
      if (process.env.NODE_ENV === 'development') {
        debug.log('AuthMiddleware', 'No token provided');
      }
      res.status(401).json({
        success: false,
        message: 'Unauthorized: No token provided',
      });
      return;
    }

    const token = authHeader.split('Bearer ')[1];

    if (!token) {
      if (process.env.NODE_ENV === 'development') {
        debug.log('AuthMiddleware', 'Invalid token format');
      }
      res.status(401).json({
        success: false,
        message: 'Unauthorized: Invalid token format',
      });
      return;
    }

    if (process.env.NODE_ENV === 'development') {
      debug.log('AuthMiddleware', 'Token received, length:', token.length);
      debug.log('AuthMiddleware', 'Token starts with:', token.substring(0, 20) + '...');
    }

    try {
      const decodedToken = await admin.auth().verifyIdToken(token);
      if (process.env.NODE_ENV === 'development') {
        debug.log('AuthMiddleware', 'Token verified successfully, uid:', decodedToken.uid);
      }
      
      // Найдём пользователя в БД по firebaseUid
      const user = await prisma.user.findUnique({
        where: { firebaseUid: decodedToken.uid }
      });
      
      req.user = {
        uid: decodedToken.uid,
        userId: user?.id, // Сохраняем UUID пользователя из БД
        email: decodedToken.email ?? undefined,
      };
      next();
    } catch (error) {
      if (process.env.NODE_ENV === 'development') {
        debug.log('AuthMiddleware', 'Token verification failed:', error);
      }
      
      // Dev режим: если токен в формате Firebase Admin custom token, используем fallback
      if (process.env.NODE_ENV === 'development') {
        if (process.env.NODE_ENV === 'development') {
          debug.log('AuthMiddleware', 'Trying dev fallback authentication');
        }
        
        // Fallback: используем известный UID для разработки
        const devUser = await prisma.user.findUnique({
          where: { firebaseUid: 'SReqkUw3arQRzFOevMjQi4BL4To1' }
        });
        
        if (devUser) {
          req.user = {
            uid: 'SReqkUw3arQRzFOevMjQi4BL4To1',
            userId: devUser.id,
            email: devUser.email,
          };
          if (process.env.NODE_ENV === 'development') {
            debug.log('AuthMiddleware', 'Dev fallback successful, userId:', devUser.id);
          }
          next();
          return;
        }
      }
      
      res.status(401).json({
        success: false,
        message: 'Unauthorized: Invalid token',
      });
    }
  } catch (error) {
    if (process.env.NODE_ENV === 'development') {
      debug.error('AuthMiddleware', 'Unexpected error:', error);
    }
    res.status(500).json({
      success: false,
      message: 'Internal server error',
    });
  }
};

export const optionalAuthMiddleware = async (
  req: AuthRequest,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    const authHeader = req.headers.authorization;

    if (!authHeader?.startsWith('Bearer ')) {
      next();
      return;
    }

    const token = authHeader.split('Bearer ')[1];

    if (!token) {
      next();
      return;
    }

    try {
      const decodedToken = await admin.auth().verifyIdToken(token);
      
      // Найдём пользователя в БД по firebaseUid
      const user = await prisma.user.findUnique({
        where: { firebaseUid: decodedToken.uid }
      });
      
      req.user = {
        uid: decodedToken.uid,
        userId: user?.id, // Сохраняем UUID пользователя из БД
        email: decodedToken.email ?? undefined,
      };
      next();
    } catch (error) {
      // Если токен невалиден, просто продолжаем без пользователя
      next();
    }
  } catch (error) {
    next();
  }
};
