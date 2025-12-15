import path from 'node:path';
import fs from 'node:fs';
import logger from './logger.js';

/**
 * Создает папки для хранения файлов пользователя
 * Структура: public/uploads/{bucket}/{userId}/
 * Бакеты: avatars, events
 */
export function createUserStorageFolders(userId: string): void {
  try {
    const basePath = path.join(process.cwd(), 'public/uploads');
    
    // Убеждаемся что базовая директория существует
    if (!fs.existsSync(basePath)) {
      fs.mkdirSync(basePath, { recursive: true });
    }

    // Создаем папки для каждого бакета
    const buckets = ['avatars', 'events'];
    
    for (const bucket of buckets) {
      const userPath = path.join(basePath, bucket, userId);
      
      if (!fs.existsSync(userPath)) {
        fs.mkdirSync(userPath, { recursive: true });
        logger.info(`[UserStorage] Created folder for user ${userId}: ${userPath}`);
      }
    }
  } catch (error: any) {
    logger.error(`[UserStorage] Error creating user folders: ${error.message}`, {
      userId,
      error: error.stack,
    });
    // Не прерываем процесс создания пользователя если ошибка в создании папок
  }
}

/**
 * Удаляет папки пользователя (используется при удалении аккаунта)
 */
export function deleteUserStorageFolders(userId: string): void {
  try {
    const basePath = path.join(process.cwd(), 'public/uploads');
    const buckets = ['avatars', 'events'];
    
    for (const bucket of buckets) {
      const userPath = path.join(basePath, bucket, userId);
      
      if (fs.existsSync(userPath)) {
        fs.rmSync(userPath, { recursive: true, force: true });
        logger.info(`[UserStorage] Deleted folder for user ${userId}: ${userPath}`);
      }
    }
  } catch (error: any) {
    logger.error(`[UserStorage] Error deleting user folders: ${error.message}`, {
      userId,
      error: error.stack,
    });
  }
}
