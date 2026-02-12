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
export function validatePassword(password: string): PasswordValidationResult {
  if (!password || typeof password !== 'string') {
    return {
      isValid: false,
      message: 'Пароль должен быть строкой',
    };
  }

  if (password.length < 8) {
    return {
      isValid: false,
      message: 'Пароль должен содержать минимум 8 символов',
    };
  }

  if (password.length > 128) {
    return {
      isValid: false,
      message: 'Пароль слишком длинный (максимум 128 символов)',
    };
  }

  // Проверка на наличие букв
  if (!/[a-zA-Z]/.test(password)) {
    return {
      isValid: false,
      message: 'Пароль должен содержать буквы (a-z, A-Z)',
    };
  }

  // Проверка на наличие цифр
  if (!/\d/.test(password)) {
    return {
      isValid: false,
      message: 'Пароль должен содержать цифры (0-9)',
    };
  }

  return {
    isValid: true,
  };
}
