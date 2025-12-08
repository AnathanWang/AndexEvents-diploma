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
declare class EventService {
    createEvent(data: CreateEventInput, createdById?: string): Promise<{
        id: string;
        title: string;
        description: string;
        category: string;
        location: string;
        latitude: number;
        longitude: number;
        dateTime: Date;
        endDateTime: Date | null;
        price: number;
        imageUrl: string | null;
        isOnline: boolean;
        status: import("../generated/prisma/index.js").$Enums.EventStatus;
        rejectionReason: string | null;
        maxParticipants: number | null;
        minAge: number | null;
        maxAge: number | null;
        createdAt: Date;
        updatedAt: Date;
        createdById: string | null;
    }>;
    getAllEvents(): Promise<{
        id: string;
        title: string;
        description: string;
        category: string;
        location: string;
        latitude: number;
        longitude: number;
        dateTime: Date;
        endDateTime: Date | null;
        price: number;
        imageUrl: string | null;
        isOnline: boolean;
        status: import("../generated/prisma/index.js").$Enums.EventStatus;
        rejectionReason: string | null;
        maxParticipants: number | null;
        minAge: number | null;
        maxAge: number | null;
        createdAt: Date;
        updatedAt: Date;
        createdById: string | null;
    }[]>;
    getEventById(eventId: string): Promise<{
        id: string;
        title: string;
        description: string;
        category: string;
        location: string;
        latitude: number;
        longitude: number;
        dateTime: Date;
        endDateTime: Date | null;
        price: number;
        imageUrl: string | null;
        isOnline: boolean;
        status: import("../generated/prisma/index.js").$Enums.EventStatus;
        rejectionReason: string | null;
        maxParticipants: number | null;
        minAge: number | null;
        maxAge: number | null;
        createdAt: Date;
        updatedAt: Date;
        createdById: string | null;
    } | null>;
}
declare const _default: EventService;
export default _default;
//# sourceMappingURL=event.service.d.ts.map