import { Router } from "express";
import eventController from "../controllers/event.controller.js";

const router = Router();

// Маршрут для создания нового события
router.post("/", eventController.createEvent.bind(eventController));
// Маршрут для получения всех событий
router.get("/", eventController.getAllEvents.bind(eventController));
// Маршрут для получения события по ID
router.get("/:id", eventController.getEventById.bind(eventController));

export default router;