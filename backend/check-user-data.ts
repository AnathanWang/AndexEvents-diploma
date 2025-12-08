import { PrismaClient } from './src/generated/prisma/index.js';

const prisma = new PrismaClient();

async function checkUserData() {
  console.log('\n=== Проверка пользователя Kirov ===');
  const user = await prisma.user.findFirst({
    where: { email: 'kirov@gmail.com' }
  });
  console.log('User:', JSON.stringify(user, null, 2));

  console.log('\n=== Все пользователи ===');
  const allUsers = await prisma.user.findMany({
    select: {
      id: true,
      email: true,
      displayName: true,
      bio: true,
      interests: true,
      photoUrl: true
    }
  });
  console.log('Total users:', allUsers.length);
  allUsers.forEach(u => console.log(JSON.stringify(u, null, 2)));

  console.log('\n=== Проверка событий ===');
  const events = await prisma.event.findMany({
    take: 2,
    include: {
      createdBy: {
        select: {
          id: true,
          displayName: true,
          email: true,
          bio: true,
          interests: true,
          photoUrl: true
        }
      }
    }
  });
  console.log('Events:', JSON.stringify(events, null, 2));

  await prisma.$disconnect();
}

checkUserData();
