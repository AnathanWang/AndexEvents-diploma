import type { Request, Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';
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
      // Verify Supabase Token
      const jwtSecret = process.env.SUPABASE_JWT_SECRET;
      if (!jwtSecret) {
        console.error('SUPABASE_JWT_SECRET is not defined in environment variables');
        throw new Error('Server configuration error');
      }

      const decoded = jwt.verify(token, jwtSecret) as jwt.JwtPayload;
      
      if (!decoded.sub) {
        throw new Error('Token missing sub claim');
      }

      if (process.env.NODE_ENV === 'development') {
        debug.log('AuthMiddleware', 'Token verified successfully, sub:', decoded.sub);
      }
      
      // Найдём пользователя в БД по supabaseUid
      const user = await prisma.user.findUnique({
        where: { supabaseUid: decoded.sub }
      });
      
      req.user = {
        uid: decoded.sub!,
        userId: user?.id, // Сохраняем UUID пользователя из БД
        email: decoded.email,
      };
      next();
    } catch (error) {
      if (process.env.NODE_ENV === 'development') {
        debug.log('AuthMiddleware', 'Token verification failed:', error);
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
      const jwtSecret = process.env.SUPABASE_JWT_SECRET;
      if (jwtSecret) {
        const decoded = jwt.verify(token, jwtSecret) as jwt.JwtPayload;
        
        if (decoded.sub) {
      // Найдём пользователя в БД по supabaseUid
      const user = await prisma.user.findUnique({
        where: { supabaseUid: decoded.sub }
      });
      
      req.user = {
        uid: decoded.sub!,
        userId: user?.id, // Сохраняем UUID пользователя из БД
        email: decoded.email,
      };
        }
      }
      next();
    } catch (error) {
      // Если токен невалиден, просто продолжаем без пользователя
      next();
    }
  } catch (error) {
    next();
  }
};
