import type { User } from '../generated/prisma/index.js';
interface CreateUserData {
    firebaseUid: string;
    email: string;
    displayName?: string;
    photoUrl?: string;
}
interface UpdateProfileData {
    displayName?: string;
    bio?: string;
    interests?: string[];
    age?: number;
    gender?: string;
    photoUrl?: string;
    isOnboardingCompleted?: boolean;
}
export declare const createUser: (data: CreateUserData) => Promise<User>;
export declare const getUserByFirebaseUid: (firebaseUid: string) => Promise<User | null>;
export declare const updateUserProfile: (userId: string, data: UpdateProfileData) => Promise<User>;
export declare const updateUserLocation: (userId: string, latitude: number, longitude: number) => Promise<void>;
export {};
//# sourceMappingURL=user.service.d.ts.map