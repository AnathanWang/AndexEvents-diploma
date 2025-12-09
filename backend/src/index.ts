import "dotenv/config";
import express from "express";
import cors from "cors";
import helmet from "helmet";
import morgan from "morgan";
import path from "path";
import eventRoutes from "./routes/event.routes.js";
import userRoutes from "./routes/user.routes.js";
import uploadRoutes from "./routes/upload.routes.js";
import logger from "./utils/logger.js";

// dotenv.config() is already loaded via 'import "dotenv/config"'

const app = express();
const PORT = process.env.PORT || 3000;

// Serve static files from public/uploads
app.use('/uploads', express.static(path.join(process.cwd(), 'public/uploads')));

// Middleware
app.use(helmet());
app.use(cors());
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// HTTP request logging
app.use(
  morgan('combined', {
    stream: {
      write: (message: string) => logger.info(message.trim()),
    },
  })
);

// Request logging
app.use((req, res, next) => {
  logger.info(`${req.method} ${req.path}`, {
    query: req.query,
    ip: req.ip,
  });
  next();
});

// Health check
app.get("/health", (req, res) => {
  res.json({
    success: true,
    status: 'healthy',
    timestamp: new Date().toISOString(),
  });
});

// Routes
app.use("/api/events", eventRoutes);
app.use("/api/users", userRoutes);
app.use("/api/upload", uploadRoutes);

app.get("/", (req, res) => {
  res.json({
    success: true,
    message: "Welcome to Andex Events API",
    version: '1.0.0',
    endpoints: {
      health: '/health',
      events: '/api/events',
      users: '/api/users',
      uploads: '/api/uploads',
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
app.use((err: Error, req: express.Request, res: express.Response, next: express.NextFunction) => {
  logger.error("Unhandled error:", {
    error: err.message,
    stack: err.stack,
    path: req.path,
    method: req.method,
  });
  
  res.status(500).json({
    success: false,
    message: process.env.NODE_ENV === 'production' 
      ? "Internal server error" 
      : err.message,
  });
});

// Start the server
app.listen(PORT, () => {
  logger.info(`Server is running on http://localhost:${PORT}`);
  logger.info(`Environment: ${process.env.NODE_ENV || 'development'}`);
  logger.info('API endpoints:');
  logger.info(`  - Health: http://localhost:${PORT}/health`);
  logger.info(`  - Events: http://localhost:${PORT}/api/events`);
  logger.info(`  - Users: http://localhost:${PORT}/api/users`);
  logger.info(`  - Uploads: http://localhost:${PORT}/api/uploads`);
});

