import type { Request, Response } from "express";
import eventService from "../services/event.service.js";
import type { AuthRequest } from "../middleware/auth.middleware.js";
import { debug } from "../utils/debug.js";

class EventController {
    async createEvent(req: AuthRequest, res: Response) {
        try {
            const eventData = req.body;
            const userId = req.user?.userId; // Получаем userId (UUID) из middleware

            if (!userId) {
                return res.status(401).json({
                    success: false,
                    message: "Unauthorized: User ID not found in database",
                });
            }

            eventData.dateTime = new Date(eventData.dateTime);

            const event = await eventService.createEvent(eventData, userId);
            res.status(201).json({
                success: true,
                data: event,
            });
        } catch (error) {
            console.error("Error creating event:", error);
            res.status(500).json({
                success: false,
                message: "Failed to create event",
            });
        }
    }
    async getAllEvents(req: Request, res: Response) {
        try {
            const { latitude, longitude, maxDistance, category, page, limit } = req.query;
            
            // Если есть координаты пользователя - ищем рядом
            if (latitude && longitude) {
                const lat = Number.parseFloat(latitude as string);
                const lon = Number.parseFloat(longitude as string);
                const distance = maxDistance ? Number.parseInt(maxDistance as string, 10) : 50000;
                const pageNum = page ? Number.parseInt(page as string, 10) : 1;
                const limitNum = limit ? Number.parseInt(limit as string, 10) : 20;
                
                if (Number.isNaN(lat) || Number.isNaN(lon) || lat < -90 || lat > 90 || lon < -180 || lon > 180) {
                    return res.status(400).json({
                        success: false,
                        message: "Invalid coordinates",
                    });
                }
                
                const result = await eventService.getNearbyEvents(
                    lat, 
                    lon, 
                    distance, 
                    category as string | undefined,
                    pageNum,
                    limitNum
                );
                
                return res.status(200).json({
                    success: true,
                    data: result,
                });
            }
            
            // Иначе возвращаем все события
            const events = await eventService.getAllEvents();
            res.status(200).json({
                success: true,
                data: { events },
            });
        } catch (error) {
            console.error("Error fetching events:", error);
            res.status(500).json({
                success: false,
                message: "Failed to fetch events",
            });
        }
    }

    async getEventById(req: Request, res: Response) {
        try {
            const { id } = req.params;
            
            if (!id) {
                return res.status(400).json({
                    success: false,
                    message: "Event ID is required",
                });
            }
            
            const event = await eventService.getEventById(id);
            if (!event) {
                return res.status(404).json({
                    success: false,
                    message: "Event not found",
                });
            }
            res.status(200).json({
                success: true,
                data: event,
            });
        } catch (error) {
            console.error("Error fetching event by ID:", error);
            res.status(500).json({
                success: false,
                message: "Failed to fetch event",
            });
        }
    }
    
    async getUserEvents(req: Request, res: Response) {
        try {
            const userId = req.params.userId || (req as any).user?.uid;
            
            if (!userId) {
                return res.status(400).json({
                    success: false,
                    message: "User ID is required",
                });
            }
            
            const events = await eventService.getUserEvents(userId);
            res.status(200).json({
                success: true,
                data: { events },
            });
        } catch (error) {
            console.error("Error fetching user events:", error);
            res.status(500).json({
                success: false,
                message: "Failed to fetch user events",
            });
        }
    }

    async participateInEvent(req: AuthRequest, res: Response) {
        try {
            const { id: eventId } = req.params;
            const { status } = req.body;
            const userId = req.user?.userId; // Получаем userId (UUID) из middleware

            if (!userId) {
                return res.status(401).json({
                    success: false,
                    message: "Unauthorized: User ID not found in database",
                });
            }

            if (!eventId || !status || (status !== 'GOING' && status !== 'INTERESTED')) {
                return res.status(400).json({
                    success: false,
                    message: "Invalid request data",
                });
            }
            
            const participation = await eventService.participateInEvent(eventId, userId, status);
            res.status(200).json({
                success: true,
                message: "Participation status updated",
                data: participation,
            });
        } catch (error) {
            console.error("Error participating in event:", error);
            res.status(500).json({
                success: false,
                message: "Failed to update participation status",
            });
        }
    }

    async cancelParticipation(req: AuthRequest, res: Response) {
        if (process.env.NODE_ENV === 'development') {
          debug.log('EventController', 'cancelParticipation called');
        }
        
        try {
            const { id: eventId } = req.params;
            const userId = req.user?.userId; // Получаем userId (UUID) из middleware

            if (process.env.NODE_ENV === 'development') {
              debug.log('EventController', { eventId, userId });
            }

            if (!userId) {
                return res.status(401).json({
                    success: false,
                    message: "Unauthorized: User ID not found in database",
                });
            }

            if (!eventId) {
                return res.status(400).json({
                    success: false,
                    message: "Event ID is required",
                });
            }

            // Validate UUID format
            const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
            if (!uuidRegex.test(eventId)) {
                 return res.status(400).json({
                    success: false,
                    message: "Invalid Event ID format",
                });
            }

            const result = await eventService.cancelParticipation(eventId, userId);
            
            res.status(200).json({
                success: true,
                message: "Participation cancelled successfully",
                data: result,
            });
        } catch (error: any) {
            if (process.env.NODE_ENV === 'development') {
              debug.error('EventController', 'Error in cancelParticipation:', error);
            }
            
            res.status(500).json({
                success: false,
                message: "Failed to cancel participation",
                error: process.env.NODE_ENV === 'development' ? error.message : undefined
            });
        }
    }

    async getEventParticipants(req: Request, res: Response) {
        try {
            const { id: eventId } = req.params;

            if (!eventId) {
                return res.status(400).json({
                    success: false,
                    message: "Event ID is required",
                });
            }

            // Verify event exists
            const event = await eventService.getEventById(eventId);
            if (!event) {
                return res.status(404).json({
                    success: false,
                    message: "Event not found",
                });
            }

            const participants = await eventService.getEventParticipants(eventId);
            res.status(200).json({
                success: true,
                data: participants,
            });
        } catch (error) {
            if (process.env.NODE_ENV === 'development') {
              debug.error('EventController', 'Error fetching event participants:', error);
            }
            res.status(500).json({
                success: false,
                message: "Failed to fetch event participants",
            });
        }
    }
}

export default new EventController();