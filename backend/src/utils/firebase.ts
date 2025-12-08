import admin from 'firebase-admin';
import { readFileSync } from 'fs';
import { resolve } from 'path';
import logger from './logger.js';

let isInitialized = false;

export const initializeFirebase = () => {
  if (isInitialized) {
    return;
  }

  try {
    const serviceAccountPath = process.env.FIREBASE_SERVICE_ACCOUNT_PATH;

    if (serviceAccountPath) {
      const serviceAccountFile = readFileSync(resolve(serviceAccountPath), 'utf8');
      const serviceAccount = JSON.parse(serviceAccountFile);
      admin.initializeApp({
        credential: admin.credential.cert(serviceAccount),
        projectId: process.env.FIREBASE_PROJECT_ID || '',
      });
    } else {
      // Fallback to environment variables
      const projectId = process.env.FIREBASE_PROJECT_ID || '';
      const privateKey = process.env.FIREBASE_PRIVATE_KEY?.replaceAll('\\n', '\n') || '';
      const clientEmail = process.env.FIREBASE_CLIENT_EMAIL || '';

      admin.initializeApp({
        credential: admin.credential.cert({
          projectId,
          privateKey,
          clientEmail,
        }),
      });
    }

    isInitialized = true;
    logger.info('Firebase Admin SDK initialized successfully');
  } catch (error) {
    logger.error('Failed to initialize Firebase Admin SDK:', error);
    throw error;
  }
};

export const sendPushNotification = async (
  fcmToken: string,
  title: string,
  body: string,
  data?: Record<string, string>
): Promise<void> => {
  try {
    const message = {
      notification: {
        title,
        body,
      },
      data: data || {},
      token: fcmToken,
    };

    await admin.messaging().send(message);
    logger.info(`Push notification sent to ${fcmToken}`);
  } catch (error) {
    logger.error('Failed to send push notification:', error);
    throw error;
  }
};

export { admin };
