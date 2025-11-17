import prisma from '../utils/prisma.js';
class EventService {
    async createEvent(data) {
        return await prisma.event.create({
            data: {
                ...data,
                price: data.price ?? 0,
                isOnline: data.isOnline ?? false,
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