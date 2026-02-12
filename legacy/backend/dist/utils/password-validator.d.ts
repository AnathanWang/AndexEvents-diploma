/**
 * Валидация пароля
 * Требования:
 * - Минимум 8 символов
 * - Содержит хотя бы одну букву (a-z, A-Z)
 * - Содержит хотя бы одну цифру (0-9)
 */
export interface PasswordValidationError {
    isValid: false;
    message: string;
}
export interface PasswordValidationSuccess {
    isValid: true;
}
export type PasswordValidationResult = PasswordValidationError | PasswordValidationSuccess;
/**
 * Валидирует пароль согласно требованиям безопасности
 */
export declare function validatePassword(password: string): PasswordValidationResult;
//# sourceMappingURL=password-validator.d.ts.map