import { PrismaClient } from "../generated/prisma/index.js";
import logger from "../utils/logger.js";

const prisma = new PrismaClient();

export type FriendshipStatus =
  | "NONE"
  | "OUTGOING_REQUEST"
  | "INCOMING_REQUEST"
  | "FRIENDS";

function normalizePair(a: string, b: string): { user1Id: string; user2Id: string } {
  return a < b ? { user1Id: a, user2Id: b } : { user1Id: b, user2Id: a };
}

export async function getFriendshipStatus(
  currentUserId: string,
  otherUserId: string,
): Promise<FriendshipStatus> {
  const { user1Id, user2Id } = normalizePair(currentUserId, otherUserId);

  const friendship = await prisma.friendship.findUnique({
    where: { user1Id_user2Id: { user1Id, user2Id } },
    select: { id: true },
  });

  if (friendship) {
    return "FRIENDS";
  }

  const outgoing = await prisma.friendRequest.findFirst({
    where: {
      requesterId: currentUserId,
      addresseeId: otherUserId,
      status: "PENDING",
    },
    select: { id: true },
  });

  if (outgoing) {
    return "OUTGOING_REQUEST";
  }

  const incoming = await prisma.friendRequest.findFirst({
    where: {
      requesterId: otherUserId,
      addresseeId: currentUserId,
      status: "PENDING",
    },
    select: { id: true },
  });

  if (incoming) {
    return "INCOMING_REQUEST";
  }

  return "NONE";
}

export async function sendFriendRequest(
  currentUserId: string,
  targetUserId: string,
): Promise<{ status: FriendshipStatus }> {
  if (currentUserId === targetUserId) {
    throw new Error("Cannot send friend request to yourself");
  }

  const targetExists = await prisma.user.findUnique({
    where: { id: targetUserId },
    select: { id: true },
  });

  if (!targetExists) {
    throw new Error("Target user not found");
  }

  const existingStatus = await getFriendshipStatus(currentUserId, targetUserId);
  if (existingStatus === "FRIENDS") {
    return { status: "FRIENDS" };
  }

  // Если есть входящий PENDING от target -> current, то принимаем его (быстрая взаимность)
  if (existingStatus === "INCOMING_REQUEST") {
    await acceptFriendRequest(currentUserId, targetUserId);
    return { status: "FRIENDS" };
  }

  // OUTGOING_REQUEST: ничего не делаем
  if (existingStatus === "OUTGOING_REQUEST") {
    return { status: "OUTGOING_REQUEST" };
  }

  // Иначе создаём/восстанавливаем запрос
  const existing = await prisma.friendRequest.findUnique({
    where: { requesterId_addresseeId: { requesterId: currentUserId, addresseeId: targetUserId } },
  });

  if (existing === null) {
    await prisma.friendRequest.create({
      data: {
        requesterId: currentUserId,
        addresseeId: targetUserId,
        status: "PENDING",
      },
    });
  } else {
    await prisma.friendRequest.update({
      where: { id: existing.id },
      data: {
        status: "PENDING",
        respondedAt: null,
      },
    });
  }

  return { status: "OUTGOING_REQUEST" };
}

export async function cancelFriendRequest(
  currentUserId: string,
  targetUserId: string,
): Promise<{ status: FriendshipStatus }> {
  const outgoing = await prisma.friendRequest.findFirst({
    where: {
      requesterId: currentUserId,
      addresseeId: targetUserId,
      status: "PENDING",
    },
  });

  if (!outgoing) {
    throw new Error("No pending outgoing request");
  }

  await prisma.friendRequest.update({
    where: { id: outgoing.id },
    data: {
      status: "CANCELED",
      respondedAt: new Date(),
    },
  });

  return { status: "NONE" };
}

export async function acceptFriendRequest(
  currentUserId: string,
  requesterUserId: string,
): Promise<{ status: FriendshipStatus }> {
  if (currentUserId === requesterUserId) {
    throw new Error("Cannot accept request from yourself");
  }

  const request = await prisma.friendRequest.findFirst({
    where: {
      requesterId: requesterUserId,
      addresseeId: currentUserId,
      status: "PENDING",
    },
  });

  if (!request) {
    throw new Error("No pending incoming request");
  }

  const { user1Id, user2Id } = normalizePair(currentUserId, requesterUserId);

  await prisma.$transaction(async (tx) => {
    await tx.friendRequest.update({
      where: { id: request.id },
      data: {
        status: "ACCEPTED",
        respondedAt: new Date(),
      },
    });

    await tx.friendship.upsert({
      where: { user1Id_user2Id: { user1Id, user2Id } },
      create: { user1Id, user2Id },
      update: {},
    });
  });

  logger.info(`[Friendship] Users are now friends: ${currentUserId} <-> ${requesterUserId}`);

  return { status: "FRIENDS" };
}

export async function declineFriendRequest(
  currentUserId: string,
  requesterUserId: string,
): Promise<{ status: FriendshipStatus }> {
  if (currentUserId === requesterUserId) {
    throw new Error("Cannot decline request from yourself");
  }

  const request = await prisma.friendRequest.findFirst({
    where: {
      requesterId: requesterUserId,
      addresseeId: currentUserId,
      status: "PENDING",
    },
  });

  if (!request) {
    throw new Error("No pending incoming request");
  }

  await prisma.friendRequest.update({
    where: { id: request.id },
    data: {
      status: "DECLINED",
      respondedAt: new Date(),
    },
  });

  return { status: "NONE" };
}

export async function listFriendRequests(
  currentUserId: string,
  type: "incoming" | "outgoing",
): Promise<any[]> {
  if (type === "incoming") {
    return prisma.friendRequest.findMany({
      where: { addresseeId: currentUserId, status: "PENDING" },
      orderBy: { createdAt: "desc" },
    });
  }

  return prisma.friendRequest.findMany({
    where: { requesterId: currentUserId, status: "PENDING" },
    orderBy: { createdAt: "desc" },
  });
}

export async function listFriends(currentUserId: string): Promise<any[]> {
  return prisma.friendship.findMany({
    where: {
      OR: [{ user1Id: currentUserId }, { user2Id: currentUserId }],
    },
    orderBy: { createdAt: "desc" },
  });
}
