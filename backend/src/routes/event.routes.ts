import { Router } from "express";
import eventController from "../controllers/event.controller.js";
import { authMiddleware } from "../middleware/auth.middleware.js";

const router = Router();

// Маршрут для создания нового события (требует авторизации)
router.post("/", authMiddleware, eventController.createEvent.bind(eventController));
// Маршрут для получения всех событий
router.get("/", eventController.getAllEvents.bind(eventController));
// Маршрут для получения событий пользователя
router.get("/user/:userId", eventController.getUserEvents.bind(eventController));
// Маршрут для получения события по ID
router.get("/:id", eventController.getEventById.bind(eventController));
// Маршрут для участия в событии (требует авторизации)
router.post(
  "/:id/participate",
  authMiddleware,
  eventController.participateInEvent.bind(eventController)
);
// Маршрут для отмены участия в событии (требует авторизации)
router.delete(
  "/:id/participate",
  authMiddleware,
  eventController.cancelParticipation.bind(eventController)
);
// Маршрут для получения списка участников события
router.get(
  "/:id/participants",
  eventController.getEventParticipants.bind(eventController)
);

export default router;