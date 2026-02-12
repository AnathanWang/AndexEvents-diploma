import type { Match, MatchAction } from "../generated/prisma/index.js";
export declare const createOrUpdateMatch: (userAId: string, userBId: string, action: MatchAction) => Promise<Match>;
/**
 * Получить все матчи пользователя
 */
export declare const getUserMatches: (userId: string) => Promise<Match[]>;
/**
 * Получить истину действий пользователя
 */
export declare const getUserActions: (userId: string, limit?: number) => Promise<Match[]>;
//# sourceMappingURL=match.service.d.ts.map