import "dotenv/config";
import express from "express";
import cors from "cors";
import helmet from "helmet";
import morgan from "morgan";
import path from "node:path";
import rateLimit from "express-rate-limit";
import eventRoutes from "./routes/event.routes.js";
import userRoutes from "./routes/user.routes.js";
import uploadRoutes from "./routes/upload.routes.js";
import matchRoutes from "./routes/match.routes.js";
import friendRoutes from "./routes/friend.routes.js";
import { fileAccessMiddleware } from "./middleware/file-access.middleware.js";
import logger from "./utils/logger.js";
import minioService from "./services/minio.service.js";

// dotenv.config() is already loaded via 'import "dotenv/config"'

const app = express();
const PORT = process.env.PORT || 3000;
const isProduction = process.env.NODE_ENV === "production";

// Middleware для проверки доступа к файлам перед отправкой
app.use("/uploads", fileAccessMiddleware);

// Serve static files from public/uploads
app.use("/uploads", express.static(path.join(process.cwd(), "public/uploads")));

// Middleware
app.use(helmet());

// CORS
// - В dev: разрешаем всё (удобно для локальной разработки)
// - В prod: разрешаем только CORS_ORIGINS (comma-separated). Запросы без Origin (mobile apps, curl) разрешаем.
const allowedCorsOrigins = (process.env.CORS_ORIGINS || "")
  .split(",")
  .map((value) => value.trim())
  .filter(Boolean);

app.use(
  cors({
    origin: (origin, callback) => {
      if (process.env.NODE_ENV !== "production") {
        return callback(null, true);
      }

      // Non-browser clients часто не отправляют Origin
      if (!origin) {
        return callback(null, true);
      }

      if (allowedCorsOrigins.length === 0) {
        return callback(new Error("CORS is not configured (CORS_ORIGINS is empty)"));
      }

      if (allowedCorsOrigins.includes(origin)) {
        return callback(null, true);
      }

      return callback(new Error("Not allowed by CORS"));
    },
    credentials: true,
    methods: ["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
    allowedHeaders: ["Content-Type", "Authorization"],
  }),
);

app.use(express.json({ limit: "10mb" }));
app.use(express.urlencoded({ extended: true, limit: "10mb" }));

// HTTP request logging
app.use(
  morgan("combined", {
    stream: {
      write: (message: string) => logger.info(message.trim()),
    },
  }),
);

// Request logging
app.use((req, res, next) => {
  logger.info(`${req.method} ${req.path}`, {
    query: req.query,
    ip: req.ip,
  });
  next();
});

// Rate limiters для защиты от brute-force атак
// В dev среде общий лимитер отключаем, чтобы не мешал разработке.
// В production лимиты можно регулировать env-переменными.
const authLimiter = rateLimit({
  windowMs: Number.parseInt(process.env.AUTH_RATE_LIMIT_WINDOW_MS || "900000", 10), // 15 минут
  max: Number.parseInt(process.env.AUTH_RATE_LIMIT_MAX || "5", 10),
  message: "Слишком много попыток входа. Пожалуйста, попробуйте позже.",
  standardHeaders: true,
  legacyHeaders: false,
  skip: (req: express.Request) => req.method !== "POST", // применяем только к POST запросам
});

const uploadLimiter = rateLimit({
  windowMs: Number.parseInt(process.env.UPLOAD_RATE_LIMIT_WINDOW_MS || "60000", 10), // 1 минута
  max: Number.parseInt(process.env.UPLOAD_RATE_LIMIT_MAX || "10", 10),
  message: "Слишком много загрузок. Пожалуйста, подождите.",
  standardHeaders: true,
  legacyHeaders: false,
});

if (isProduction && process.env.GENERAL_RATE_LIMIT_DISABLED !== "1") {
  const generalLimiter = rateLimit({
    windowMs: Number.parseInt(
      process.env.GENERAL_RATE_LIMIT_WINDOW_MS || "900000",
      10,
    ), // 15 минут
    max: Number.parseInt(process.env.GENERAL_RATE_LIMIT_MAX || "100", 10),
    standardHeaders: true,
    legacyHeaders: false,
    handler: (req, res, _next, options) => {
      res.status(options.statusCode).json({
        success: false,
        message: "Too many requests",
      });
    },
  });

  // Применяем general limiter ко всем маршрутам (только production)
  app.use(generalLimiter);
}

// Health check
app.get("/health", (req, res) => {
  res.json({
    success: true,
    status: "healthy",
    timestamp: new Date().toISOString(),
  });
});

// Routes с rate limiters
app.use("/api/events", eventRoutes);

// Защищаем POST /api/users (создание пользователя) от brute-force/спама.
// authLimiter пропускает все методы кроме POST (см. skip)
app.use("/api/users", authLimiter);

app.use("/api/users", userRoutes);
app.use("/api/matches", matchRoutes);
app.use("/api/friends", friendRoutes);
app.use("/api/upload", uploadLimiter, uploadRoutes);

app.get("/", (req, res) => {
  res.json({
    success: true,
    message: "Welcome to Andex Events API",
    version: "1.0.0",
    endpoints: {
      health: "/health",
      events: "/api/events",
      users: "/api/users",
      matches: "/api/matches",
      friends: "/api/friends",
      uploads: "/api/uploads",
    },
  });
});

// 404 handler
app.use((req, res) => {
  logger.warn(`404 - Route not found: ${req.method} ${req.path}`);
  res.status(404).json({
    success: false,
    message: "Endpoint not found",
  });
});

// Error handler
app.use(
  (
    err: Error,
    req: express.Request,
    res: express.Response,
    next: express.NextFunction,
  ) => {
    logger.error("Unhandled error:", {
      error: err.message,
      stack: err.stack,
      path: req.path,
      method: req.method,
    });

    res.status(500).json({
      success: false,
      message:
        process.env.NODE_ENV === "production"
          ? "Internal server error"
          : err.message,
    });
  },
);

// Start the server
const startServer = async () => {
  try {
    // Инициализируем MinIO перед запуском сервера
    await minioService.initialize();
    logger.info('[MinIO] ✅ Хранилище инициализировано');
  } catch (error: any) {
    logger.warn(`[MinIO] ⚠️ Не удалось подключиться к MinIO: ${error.message}`);
    logger.warn('[MinIO] Сервер запустится без MinIO. Загрузка файлов будет недоступна.');
  }

  app.listen(PORT, () => {
    logger.info(`Server is running on http://localhost:${PORT}`);
    logger.info(`Environment: ${process.env.NODE_ENV || "development"}`);
    logger.info("API endpoints:");
    logger.info(`  - Health: http://localhost:${PORT}/health`);
    logger.info(`  - Events: http://localhost:${PORT}/api/events`);
    logger.info(`  - Users: http://localhost:${PORT}/api/users`);
    logger.info(`  - Matches: http://localhost:${PORT}/api/matches`);
    logger.info(`  - Uploads: http://localhost:${PORT}/api/uploads`);
    logger.info(`  - MinIO Console: http://localhost:9001`);
  });
};

startServer();
