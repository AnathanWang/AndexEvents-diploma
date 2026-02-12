/**
 * Создает папки для хранения файлов пользователя
 * Структура: public/uploads/{bucket}/{userId}/
 * Бакеты: avatars, events
 */
export declare function createUserStorageFolders(userId: string): void;
/**
 * Удаляет папки пользователя (используется при удалении аккаунта)
 */
export declare function deleteUserStorageFolders(userId: string): void;
//# sourceMappingURL=user-storage.d.ts.map