import { PrismaClient } from '../generated/prisma/index.js';

// Singleton pattern - только один экземпляр Prisma Client
const prisma = new PrismaClient({
  log: process.env.NODE_ENV === 'development' 
    ? ['query', 'info', 'warn', 'error']
    : ['warn', 'error'], // В production логируем только ошибки
});

export default prisma;