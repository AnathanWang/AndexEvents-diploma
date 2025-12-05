import type { Request, Response, NextFunction } from 'express';
import admin from 'firebase-admin';
import prisma from '../utils/prisma.js';

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
      console.log('DEBUG: No token provided');
      res.status(401).json({
        success: false,
        message: 'Unauthorized: No token provided',
      });
      return;
    }

    const token = authHeader.split('Bearer ')[1];

    if (!token) {
      console.log('DEBUG: Invalid token format');
      res.status(401).json({
        success: false,
        message: 'Unauthorized: Invalid token format',
      });
      return;
    }

    console.log('DEBUG: Token received, length:', token.length);
    console.log('DEBUG: Token starts with:', token.substring(0, 20) + '...');

    try {
      const decodedToken = await admin.auth().verifyIdToken(token);
      console.log('DEBUG: Token verified successfully, uid:', decodedToken.uid);
      
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
      console.log('DEBUG: Token verification failed:', error);
      
      // Dev режим: если токен в формате Firebase Admin custom token, используем fallback
      if (process.env.NODE_ENV === 'development') {
        console.log('DEBUG: Trying dev fallback authentication');
        
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
          console.log('DEBUG: Dev fallback successful, userId:', devUser.id);
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
    console.error('DEBUG: Auth middleware error:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error',
    });
  }
};
