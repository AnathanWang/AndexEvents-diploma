import { PrismaClient } from '../generated/prisma/index.js';
// Singleton pattern - только один экземпляр Prisma Client
const prisma = new PrismaClient({
    log: ['query', 'info', 'warn', 'error'], // Логирование SQL запросов
});
export default prisma;
//# sourceMappingURL=prisma.js.map