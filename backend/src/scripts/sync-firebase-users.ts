import admin from 'firebase-admin';
import { PrismaClient } from '../generated/prisma/index.js';
import logger from '../utils/logger.js';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const prisma = new PrismaClient();

// Инициализация Firebase Admin
const serviceAccountPath = path.resolve(__dirname, '../../firebase-service-account.json');
admin.initializeApp({
  credential: admin.credential.cert(serviceAccountPath),
});

async function syncFirebaseUsers() {
  try {
    logger.info('Starting Firebase users synchronization...');
    
    // Получаем всех пользователей из Firebase Auth
    const listUsersResult = await admin.auth().listUsers();
    const firebaseUsers = listUsersResult.users;
    
    logger.info(`Found ${firebaseUsers.length} users in Firebase Auth`);
    
    let created = 0;
    let skipped = 0;
    
    for (const firebaseUser of firebaseUsers) {
      try {
        // Проверяем, существует ли пользователь в БД
        const existingUser = await prisma.user.findUnique({
          where: { firebaseUid: firebaseUser.uid }
        });
        
        if (existingUser) {
          logger.info(`User ${firebaseUser.email} already exists in database, skipping...`);
          skipped++;
          continue;
        }
        
        // Создаём пользователя в БД
        const newUser = await prisma.user.create({
          data: {
            firebaseUid: firebaseUser.uid,
            email: firebaseUser.email || '',
            displayName: firebaseUser.displayName || firebaseUser.email?.split('@')[0] || 'User',
            photoUrl: firebaseUser.photoURL || null,
          },
        });
        
        logger.info(`Created user: ${newUser.email} (ID: ${newUser.id})`);
        created++;
      } catch (error) {
        logger.error(`Error creating user ${firebaseUser.email}:`, error);
      }
    }
    
    logger.info(`Synchronization completed. Created: ${created}, Skipped: ${skipped}`);
    
    // Показываем всех пользователей в БД
    const allUsers = await prisma.user.findMany({
      select: {
        id: true,
        email: true,
        displayName: true,
        firebaseUid: true,
      }
    });
    
    logger.info('Current users in database:');
    console.table(allUsers);
    
  } catch (error) {
    logger.error('Error during synchronization:', error);
    throw error;
  } finally {
    await prisma.$disconnect();
  }
}

try {
  await syncFirebaseUsers();
  logger.info('Script completed successfully');
  process.exit(0);
} catch (error) {
  logger.error('Script failed:', error);
  process.exit(1);
}
