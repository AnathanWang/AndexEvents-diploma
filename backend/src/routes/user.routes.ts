import express from "express";
import { authMiddleware } from "../middleware/auth.middleware.js";
import * as userController from "../controllers/user.controller.js";

const router = express.Router();

// Регистрация/создание пользователя: только с валидным Supabase JWT
router.post("/", authMiddleware, userController.createUser);

// Защищенные endpoints (требуют авторизации через Supabase token)
router.get("/me", authMiddleware, userController.getCurrentUser);
router.put("/me", authMiddleware, userController.updateProfile);
router.put("/me/location", authMiddleware, userController.updateLocation);
router.get("/matches", authMiddleware, userController.getMatches);

export default router;
