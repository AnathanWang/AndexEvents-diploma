package handler

import (
	"bytes"
	"crypto/rand"
	"encoding/hex"
	"fmt"
	"io"
	"net/http"
	"path"
	"strconv"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"go.uber.org/zap"

	"github.com/AnathanWang/andexevents/services/upload-service/internal/middleware"
	"github.com/AnathanWang/andexevents/services/upload-service/internal/repository"
	"github.com/AnathanWang/andexevents/services/upload-service/internal/storage"
)

type UploadHandler struct {
	logger        *zap.Logger
	userRepo      *repository.UserRepository
	minio         *storage.MinioClient
	publicBaseURL string
}

func NewUploadHandler(logger *zap.Logger, userRepo *repository.UserRepository, minioClient *storage.MinioClient, publicBaseURL string) *UploadHandler {
	return &UploadHandler{logger: logger, userRepo: userRepo, minio: minioClient, publicBaseURL: strings.TrimRight(strings.TrimSpace(publicBaseURL), "/")}
}

func (h *UploadHandler) UploadFile(c *gin.Context) {
	bucket := c.Query("bucket")
	if bucket == "" {
		bucket = "events"
	}
	bucket = strings.ToLower(strings.TrimSpace(bucket))

	if !storage.AllowedBucket(bucket) {
		c.JSON(http.StatusBadRequest, UploadResponse{Success: false, Message: "Invalid bucket name"})
		return
	}

	userID, ok := middleware.GetDBUserID(c)
	if !ok {
		c.JSON(http.StatusUnauthorized, UploadResponse{Success: false, Message: "Unauthorized"})
		return
	}

	fileHeader, err := c.FormFile("file")
	if err != nil {
		c.JSON(http.StatusBadRequest, UploadResponse{Success: false, Message: "No file uploaded"})
		return
	}

	// Size limits: match Node.
	maxSize := int64(10 * 1024 * 1024)
	if bucket == "avatars" {
		maxSize = int64(5 * 1024 * 1024)
	}
	if fileHeader.Size > 0 && fileHeader.Size > maxSize {
		c.JSON(http.StatusBadRequest, UploadResponse{Success: false, Message: fmt.Sprintf("File too large (max %s)", humanBytes(maxSize))})
		return
	}

	originalName := fileHeader.Filename
	ext := strings.ToLower(path.Ext(originalName))
	if ext == "" {
		ext = ".jpg"
	}
	if !isAllowedExt(ext) {
		c.JSON(http.StatusBadRequest, UploadResponse{Success: false, Message: "Invalid file extension. Only jpg, png, gif, webp are allowed"})
		return
	}

	filename := generateFilename(ext)
	objectName := fmt.Sprintf("%s/%s", userID, filename)

	file, err := fileHeader.Open()
	if err != nil {
		h.logger.Warn("Failed to open uploaded file", zap.Error(err))
		c.JSON(http.StatusInternalServerError, UploadResponse{Success: false, Message: "Upload failed"})
		return
	}
	defer file.Close()

	// Sniff first bytes for content type. We intentionally keep validation permissive like Node.
	sniff := make([]byte, 512)
	n, _ := io.ReadFull(file, sniff)
	if n < 0 {
		n = 0
	}
	sniff = sniff[:n]

	reader := io.MultiReader(bytes.NewReader(sniff), file)
	contentType := storage.GuessContentType(originalName, sniff, fileHeader.Header.Get("Content-Type"))

	_, putErr := h.minio.PutObject(c.Request.Context(), bucket, objectName, reader, fileHeader.Size, contentType)
	if putErr != nil {
		h.logger.Error("Failed to upload to MinIO", zap.String("bucket", bucket), zap.String("object", objectName), zap.Error(putErr))
		c.JSON(http.StatusInternalServerError, UploadResponse{Success: false, Message: "Upload failed"})
		return
	}

	fileURL := h.buildPublicURL(c, bucket, userID, filename)

	if bucket == "avatars" {
		if err := h.userRepo.UpdateUserPhotoURL(c.Request.Context(), userID, fileURL); err != nil {
			h.logger.Warn("Failed to update user photoUrl", zap.String("userID", userID), zap.Error(err))
			// Keep upload successful even if DB update fails (matches Node spirit).
		}
	}

	c.JSON(http.StatusOK, UploadResponse{
		Success: true,
		FileURL: fileURL,
		File: &FileObject{
			Name:   filename,
			Size:   fileHeader.Size,
			Bucket: bucket,
		},
	})
}

func isAllowedExt(ext string) bool {
	switch ext {
	case ".jpg", ".jpeg", ".png", ".gif", ".webp":
		return true
	default:
		return false
	}
}

func generateFilename(ext string) string {
	b := make([]byte, 4)
	_, _ = rand.Read(b)
	suffix := hex.EncodeToString(b)
	return fmt.Sprintf("%d-%s%s", time.Now().UnixMilli(), suffix, ext)
}

func humanBytes(size int64) string {
	mb := float64(size) / 1024.0 / 1024.0
	return strconv.FormatFloat(mb, 'f', 0, 64) + "MB"
}

func (h *UploadHandler) buildPublicURL(c *gin.Context, bucket, userID, filename string) string {
	// Prefer explicit base URL override (useful behind gateways).
	if h.publicBaseURL != "" {
		return h.publicBaseURL + "/uploads/" + bucket + "/" + userID + "/" + filename
	}

	proto := c.GetHeader("X-Forwarded-Proto")
	if proto == "" {
		if c.Request.TLS != nil {
			proto = "https"
		} else {
			proto = "http"
		}
	}

	host := firstForwardedValue(c.GetHeader("X-Forwarded-Host"))
	if host == "" {
		host = c.Request.Host
	}

	return fmt.Sprintf("%s://%s/uploads/%s/%s/%s", proto, host, bucket, userID, filename)
}

func firstForwardedValue(v string) string {
	v = strings.TrimSpace(v)
	if v == "" {
		return ""
	}
	parts := strings.Split(v, ",")
	return strings.TrimSpace(parts[0])
}
