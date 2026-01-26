import express from "express";
import { authMiddleware } from "../middleware/auth.middleware.js";
import * as matchController from "../controllers/match.controller.js";

const router = express.Router();

// Защищённые endpoints (требуют авторизации через Supabase token)
router.get("/", authMiddleware, matchController.getMyMutualMatches);
router.get("/actions", authMiddleware, matchController.getMyActions);
router.post("/like", authMiddleware, matchController.sendLike);
router.post("/dislike", authMiddleware, matchController.sendDislike);
router.post("/super-like", authMiddleware, matchController.sendSuperLike);

export default router;
