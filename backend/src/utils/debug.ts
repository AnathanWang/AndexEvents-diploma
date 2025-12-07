/**
 * Debug логирование - активируется только в development режиме
 */

const isDev = process.env.NODE_ENV === 'development';

export const debug = {
  log: (label: string, ...args: unknown[]) => {
    if (isDev) {
      console.log(`[${label}]`, ...args);
    }
  },
  error: (label: string, ...args: unknown[]) => {
    if (isDev) {
      console.error(`[${label}]`, ...args);
    }
  },
};
