import prisma from '../utils/prisma.js';

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
        return await prisma.event.create({
            data: {
                ...data,
                price: data.price ?? 0,
                isOnline: data.isOnline ?? false,
                createdBy: createdById 
                    ? { connect: { id: createdById } }
                    : undefined,
            },
        });
    }
    async getAllEvents(){
        return await prisma.event.findMany({
            orderBy: {createdAt: 'desc'},
        });
    }
    async getEventById(eventId: string) {
        return await prisma.event.findUnique({
             where: { id: eventId },
        });
    }
}

export default new EventService();