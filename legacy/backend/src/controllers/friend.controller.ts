import type { Response } from "express";
import type { AuthRequest } from "../middleware/auth.middleware.js";
import * as friendService from "../services/friend.service.js";
import logger from "../utils/logger.js";

/**
 * GET /api/friends/status/:userId
 */
export async function getStatus(req: AuthRequest, res: Response): Promise<void> {
  try {
    const currentUserId = req.user?.userId;
    if (!currentUserId) {
      res.status(401).json({ success: false, message: "Unauthorized: User ID not found" });
      return;
    }

    const otherUserId = req.params.userId;
    if (!otherUserId) {
      res.status(400).json({ success: false, message: "userId is required" });
      return;
    }

    if (otherUserId === currentUserId) {
      res.status(200).json({ success: true, data: { status: "FRIENDS" } });
      return;
    }

    const status = await friendService.getFriendshipStatus(currentUserId, otherUserId);
    res.status(200).json({ success: true, data: { status } });
  } catch (error) {
    logger.error("Error getting friendship status:", error);
    res.status(500).json({ success: false, message: "Failed to get friendship status" });
  }
}

/**
 * POST /api/friends/requests/:userId
 */
export async function sendRequest(req: AuthRequest, res: Response): Promise<void> {
  try {
    const currentUserId = req.user?.userId;
    if (!currentUserId) {
      res.status(401).json({ success: false, message: "Unauthorized: User ID not found" });
      return;
    }

    const targetUserId = req.params.userId;
    if (!targetUserId) {
      res.status(400).json({ success: false, message: "userId is required" });
      return;
    }

    const result = await friendService.sendFriendRequest(currentUserId, targetUserId);
    res.status(200).json({ success: true, data: result });
  } catch (error: any) {
    const message = String(error?.message || "Failed to send friend request");

    if (message.includes("yourself")) {
      res.status(400).json({ success: false, message });
      return;
    }

    if (message.includes("not found")) {
      res.status(404).json({ success: false, message });
      return;
    }

    logger.error("Error sending friend request:", error);
    res.status(500).json({ success: false, message: "Failed to send friend request" });
  }
}

/**
 * DELETE /api/friends/requests/:userId
 */
export async function cancelRequest(req: AuthRequest, res: Response): Promise<void> {
  try {
    const currentUserId = req.user?.userId;
    if (!currentUserId) {
      res.status(401).json({ success: false, message: "Unauthorized: User ID not found" });
      return;
    }

    const targetUserId = req.params.userId;
    if (!targetUserId) {
      res.status(400).json({ success: false, message: "userId is required" });
      return;
    }

    const result = await friendService.cancelFriendRequest(currentUserId, targetUserId);
    res.status(200).json({ success: true, data: result });
  } catch (error: any) {
    const message = String(error?.message || "Failed to cancel friend request");

    if (message.includes("No pending outgoing request")) {
      res.status(404).json({ success: false, message });
      return;
    }

    logger.error("Error canceling friend request:", error);
    res.status(500).json({ success: false, message: "Failed to cancel friend request" });
  }
}

/**
 * POST /api/friends/requests/:userId/accept
 * Где :userId — это requester (кто отправил запрос)
 */
export async function acceptRequest(req: AuthRequest, res: Response): Promise<void> {
  try {
    const currentUserId = req.user?.userId;
    if (!currentUserId) {
      res.status(401).json({ success: false, message: "Unauthorized: User ID not found" });
      return;
    }

    const requesterUserId = req.params.userId;
    if (!requesterUserId) {
      res.status(400).json({ success: false, message: "userId is required" });
      return;
    }

    const result = await friendService.acceptFriendRequest(currentUserId, requesterUserId);
    res.status(200).json({ success: true, data: result });
  } catch (error: any) {
    const message = String(error?.message || "Failed to accept friend request");

    if (message.includes("No pending incoming request")) {
      res.status(404).json({ success: false, message });
      return;
    }

    if (message.includes("yourself")) {
      res.status(400).json({ success: false, message });
      return;
    }

    logger.error("Error accepting friend request:", error);
    res.status(500).json({ success: false, message: "Failed to accept friend request" });
  }
}

/**
 * POST /api/friends/requests/:userId/decline
 * Где :userId — это requester (кто отправил запрос)
 */
export async function declineRequest(req: AuthRequest, res: Response): Promise<void> {
  try {
    const currentUserId = req.user?.userId;
    if (!currentUserId) {
      res.status(401).json({ success: false, message: "Unauthorized: User ID not found" });
      return;
    }

    const requesterUserId = req.params.userId;
    if (!requesterUserId) {
      res.status(400).json({ success: false, message: "userId is required" });
      return;
    }

    const result = await friendService.declineFriendRequest(currentUserId, requesterUserId);
    res.status(200).json({ success: true, data: result });
  } catch (error: any) {
    const message = String(error?.message || "Failed to decline friend request");

    if (message.includes("No pending incoming request")) {
      res.status(404).json({ success: false, message });
      return;
    }

    if (message.includes("yourself")) {
      res.status(400).json({ success: false, message });
      return;
    }

    logger.error("Error declining friend request:", error);
    res.status(500).json({ success: false, message: "Failed to decline friend request" });
  }
}

/**
 * GET /api/friends/requests?type=incoming|outgoing
 */
export async function listRequests(req: AuthRequest, res: Response): Promise<void> {
  try {
    const currentUserId = req.user?.userId;
    if (!currentUserId) {
      res.status(401).json({ success: false, message: "Unauthorized: User ID not found" });
      return;
    }

    const typeRaw = (req.query.type as string | undefined) || "incoming";
    const type = typeRaw === "outgoing" ? "outgoing" : "incoming";

    const requests = await friendService.listFriendRequests(currentUserId, type);

    res.status(200).json({ success: true, data: requests });
  } catch (error) {
    logger.error("Error listing friend requests:", error);
    res.status(500).json({ success: false, message: "Failed to list friend requests" });
  }
}

/**
 * GET /api/friends
 */
export async function listFriends(req: AuthRequest, res: Response): Promise<void> {
  try {
    const currentUserId = req.user?.userId;
    if (!currentUserId) {
      res.status(401).json({ success: false, message: "Unauthorized: User ID not found" });
      return;
    }

    const friends = await friendService.listFriends(currentUserId);
    res.status(200).json({ success: true, data: friends });
  } catch (error) {
    logger.error("Error listing friends:", error);
    res.status(500).json({ success: false, message: "Failed to list friends" });
  }
}
