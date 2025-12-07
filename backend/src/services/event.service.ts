import prisma from '../utils/prisma.js';
import { debug } from '../utils/debug.js';

interface CreateEventInput {
    title: string;
    description: string;
    category: string;
    location: string;
    latitude: number;
    longitude: number;
    dateTime: Date;
    price?: number;
    imageUrl?: string;
    isOnline: boolean;
    createdById: string;
}

class EventService {
    async createEvent(data: CreateEventInput, createdById?: string) {
        // Создаем событие с координатами и PostGIS точкой
        const result = await prisma.$queryRaw<[{id: string}]>`
            INSERT INTO "Event" (
                id, title, description, category, location, 
                latitude, longitude, "locationGeo",
                "dateTime", price, "imageUrl", "isOnline", 
                status, "createdById", "createdAt", "updatedAt"
            ) VALUES (
                gen_random_uuid()::text,
                ${data.title},
                ${data.description},
                ${data.category},
                ${data.location},
                ${data.latitude},
                ${data.longitude},
                ST_SetSRID(ST_MakePoint(${data.longitude}, ${data.latitude}), 4326)::geography,
                ${data.dateTime},
                ${data.price ?? 0},
                ${data.imageUrl ?? null},
                ${data.isOnline ?? false},
                'APPROVED'::"EventStatus",
                ${createdById ?? null},
                NOW(),
                NOW()
            )
            RETURNING id
        `;
        
        // Получаем созданное событие
        return await prisma.event.findUnique({
            where: { id: result[0].id },
            include: {
                createdBy: {
                    select: {
                        id: true,
                        displayName: true,
                        photoUrl: true,
                    },
                },
            },
        });
    }
    async getAllEvents(){
        return await prisma.event.findMany({
            where: {
                status: 'APPROVED',
            },
            distinct: ['id'],
            orderBy: {createdAt: 'desc'},
            include: {
                createdBy: {
                    select: {
                        id: true,
                        displayName: true,
                        photoUrl: true,
                    },
                },
                _count: {
                    select: {
                        participants: true,
                    },
                },
            },
        });
    }
    
    async getNearbyEvents(
        userLat: number, 
        userLon: number, 
        maxDistance: number = 50000, // метры
        category?: string,
        page: number = 1,
        limit: number = 20
    ) {
        const offset = (page - 1) * limit;
        
        // Raw SQL для PostGIS запроса
        const events = await prisma.$queryRaw<any[]>`
            SELECT 
                e.*,
                ST_Distance(
                    e."locationGeo",
                    ST_SetSRID(ST_MakePoint(${userLon}, ${userLat}), 4326)::geography
                ) as distance,
                json_build_object(
                    'id', u.id,
                    'displayName', u."displayName",
                    'photoUrl', u."photoUrl"
                ) as "createdBy",
                COUNT(p.id) as "participantCount"
            FROM "Event" e
            LEFT JOIN "User" u ON e."createdById" = u.id
            LEFT JOIN "Participant" p ON e.id = p."eventId"
            WHERE 
                e.status = 'APPROVED'
                AND e."isOnline" = false
                AND ST_DWithin(
                    e."locationGeo",
                    ST_SetSRID(ST_MakePoint(${userLon}, ${userLat}), 4326)::geography,
                    ${maxDistance}
                )
                ${category ? prisma.$queryRaw`AND e.category = ${category}` : prisma.$queryRaw``}
            GROUP BY e.id, u.id
            ORDER BY distance ASC
            LIMIT ${limit}
            OFFSET ${offset}
        `;
        
        // Подсчет общего количества
        const totalResult = await prisma.$queryRaw<[{count: bigint}]>`
            SELECT COUNT(DISTINCT e.id) as count
            FROM "Event" e
            WHERE 
                e.status = 'APPROVED'
                AND e."isOnline" = false
                AND ST_DWithin(
                    e."locationGeo",
                    ST_SetSRID(ST_MakePoint(${userLon}, ${userLat}), 4326)::geography,
                    ${maxDistance}
                )
                ${category ? prisma.$queryRaw`AND e.category = ${category}` : prisma.$queryRaw``}
        `;
        
        const total = Number(totalResult[0].count);
        
        return {
            events,
            pagination: {
                page,
                limit,
                total,
                totalPages: Math.ceil(total / limit),
            },
        };
    }
    
    async getEventById(eventId: string) {
        return await prisma.event.findUnique({
             where: { id: eventId },
             include: {
                createdBy: {
                    select: {
                        id: true,
                        displayName: true,
                        photoUrl: true,
                    },
                },
                _count: {
                    select: {
                        participants: true,
                    },
                },
            },
        });
    }
    
    async getUserEvents(userId: string) {
        return await prisma.event.findMany({
            where: {
                createdById: userId,
                status: 'APPROVED',
            },
            orderBy: {
                createdAt: 'desc',
            },
            include: {
                createdBy: {
                    select: {
                        id: true,
                        displayName: true,
                        photoUrl: true,
                    },
                },
                _count: {
                    select: {
                        participants: true,
                    },
                },
            },
        });
    }
    async participateInEvent(eventId: string, userId: string, status: 'GOING' | 'INTERESTED') {
        const event = await prisma.event.findUnique({ where: { id: eventId } });
        if (!event) {
            throw new Error('Event not found');
        }
        if(event.status !== 'APPROVED') {
            throw new Error('Cannot participate in unapproved event');
        }

        const participation = await prisma.participant.upsert({
            where: {
                userId_eventId: {
                    eventId,
                    userId,
                },
            },
            update: {
                status: status as any,
                updatedAt: new Date(),
            },
            create: {
                userId: userId,
                eventId: eventId,
                status: status as any,
            },
        });

        return participation;
    }

    async cancelParticipation(eventId: string, userId: string) {
        if (process.env.NODE_ENV === 'development') {
          debug.log('EventService', `cancelParticipation called for eventId=${eventId}, userId=${userId}`);
        }
        try {
            const participation = await prisma.participant.delete({
                where: {
                    userId_eventId: {
                        eventId,
                        userId,
                    },
                },
            });
            if (process.env.NODE_ENV === 'development') {
              debug.log('EventService', 'Participation deleted successfully');
            }
            return participation;
        } catch (error: any) {
            if (process.env.NODE_ENV === 'development') {
              debug.error('EventService', 'Error in cancelParticipation:', error);
            }
            // Если запись не найдена (P2025), возвращаем пустой результат, как будто удалили
            if (error.code === 'P2025') {
                return { count: 0 };
            }
            throw error;
        }
    }
    
    async getEventParticipants(eventId: string) {
        return await prisma.participant.findMany({
            where: { eventId },
            include: {
                user: {
                    select: {
                        id: true,
                        displayName: true,
                        photoUrl: true,
                        email: true,
                    },
                },
            },
            orderBy: {
                joinedAt: 'desc',
            },
        });
    }
}

export default new EventService();