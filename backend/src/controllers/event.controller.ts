import type { Request, Response } from "express";
import eventService from "../services/event.service.js";
import type { AuthRequest } from "../middleware/auth.middleware.js";

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
}

export default new EventController();