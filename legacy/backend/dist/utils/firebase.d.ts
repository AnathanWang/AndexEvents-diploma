import admin from 'firebase-admin';
export declare const initializeFirebase: () => void;
export declare const sendPushNotification: (fcmToken: string, title: string, body: string, data?: Record<string, string>) => Promise<void>;
export { admin };
//# sourceMappingURL=firebase.d.ts.map