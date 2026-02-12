import eventService from "../services/event.service.js";
class EventController {
    async createEvent(req, res) {
        try {
            const eventData = req.body;
            eventData.dateTime = new Date(eventData.dateTime);
            const event = await eventService.createEvent(eventData);
            res.status(201).json({
                success: true,
                data: event,
            });
        }
        catch (error) {
            console.error("Error creating event:", error);
            res.status(500).json({
                success: false,
                message: "Failed to create event",
            });
        }
    }
    async getAllEvents(req, res) {
        try {
            const events = await eventService.getAllEvents();
            res.status(200).json({
                success: true,
                data: events,
            });
        }
        catch (error) {
            console.error("Error fetching events:", error);
            res.status(500).json({
                success: false,
                message: "Failed to fetch events",
            });
        }
    }
    async getEventById(req, res) {
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
        }
        catch (error) {
            console.error("Error fetching event by ID:", error);
            res.status(500).json({
                success: false,
                message: "Failed to fetch event",
            });
        }
    }
}
export default new EventController();
//# sourceMappingURL=event.controller.js.map