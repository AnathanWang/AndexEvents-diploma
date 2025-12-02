import { PrismaClient } from './src/generated/prisma/index.js';

const prisma = new PrismaClient();

async function main() {
  const kirovUser = await prisma.user.findFirst({
    where: {
      email: {
        contains: 'kirov'
      }
    }
  });

  if (!kirovUser) {
    console.log('Пользователь kirov не найден');
    return;
  }

  console.log('Найден пользователь:', kirovUser.email, 'ID:', kirovUser.id);

  const result = await prisma.event.updateMany({
    data: {
      createdById: kirovUser.id
    }
  });

  console.log('Обновлено событий:', result.count);
}

main()
  .then(() => prisma.$disconnect())
  .catch((e) => {
    console.error(e);
    prisma.$disconnect();
  });
