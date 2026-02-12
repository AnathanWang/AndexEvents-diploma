export type FriendshipStatus = "NONE" | "OUTGOING_REQUEST" | "INCOMING_REQUEST" | "FRIENDS";
export declare function getFriendshipStatus(currentUserId: string, otherUserId: string): Promise<FriendshipStatus>;
export declare function sendFriendRequest(currentUserId: string, targetUserId: string): Promise<{
    status: FriendshipStatus;
}>;
export declare function cancelFriendRequest(currentUserId: string, targetUserId: string): Promise<{
    status: FriendshipStatus;
}>;
export declare function acceptFriendRequest(currentUserId: string, requesterUserId: string): Promise<{
    status: FriendshipStatus;
}>;
export declare function declineFriendRequest(currentUserId: string, requesterUserId: string): Promise<{
    status: FriendshipStatus;
}>;
export declare function listFriendRequests(currentUserId: string, type: "incoming" | "outgoing"): Promise<any[]>;
export declare function listFriends(currentUserId: string): Promise<any[]>;
//# sourceMappingURL=friend.service.d.ts.map