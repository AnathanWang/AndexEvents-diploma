/**
 * Debug логирование - активируется только в development режиме
 */
const isDev = process.env.NODE_ENV === 'development';
export const debug = {
    log: (label, ...args) => {
        if (isDev) {
            console.log(`[${label}]`, ...args);
        }
    },
    error: (label, ...args) => {
        if (isDev) {
            console.error(`[${label}]`, ...args);
        }
    },
};
//# sourceMappingURL=debug.js.map