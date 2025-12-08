import prisma from '../utils/prisma.js';
class EventService {
    async createEvent(data, createdById) {
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
    async getAllEvents() {
        return await prisma.event.findMany({
            orderBy: { createdAt: 'desc' },
        });
    }
    async getEventById(eventId) {
        return await prisma.event.findUnique({
            where: { id: eventId },
        });
    }
}
export default new EventService();
//# sourceMappingURL=event.service.js.map