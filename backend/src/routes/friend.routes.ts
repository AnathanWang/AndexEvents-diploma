import express from "express";
import { authMiddleware } from "../middleware/auth.middleware.js";
import * as friendController from "../controllers/friend.controller.js";

const router = express.Router();

// Все endpoints защищены (требуют Supabase JWT)
router.get("/status/:userId", authMiddleware, friendController.getStatus);
router.get("/requests", authMiddleware, friendController.listRequests);
router.post("/requests/:userId", authMiddleware, friendController.sendRequest);
router.delete("/requests/:userId", authMiddleware, friendController.cancelRequest);
router.post("/requests/:userId/accept", authMiddleware, friendController.acceptRequest);
router.post("/requests/:userId/decline", authMiddleware, friendController.declineRequest);
router.get("/", authMiddleware, friendController.listFriends);

export default router;
