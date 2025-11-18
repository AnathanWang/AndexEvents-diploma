import type { Request, Response, NextFunction } from 'express';
import admin from 'firebase-admin';

export interface AuthRequest extends Request {
  user?: {
    uid: string;
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

    if (!authHeader || !authHeader.startsWith('Bearer ')) {
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
      req.user = {
        uid: decodedToken.uid,
        email: decodedToken.email ?? undefined,
      };
      next();
    } catch (error) {
      console.log('DEBUG: Token verification failed:', error);
      res.status(401).json({
        success: false,
        message: 'Unauthorized: Invalid token',
      });
    }
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Internal server error',
    });
  }
};
