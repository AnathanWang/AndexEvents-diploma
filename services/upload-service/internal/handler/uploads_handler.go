package handler

import (
	"net/http"
	"regexp"
	"strings"

	"github.com/gin-gonic/gin"
	"github.com/minio/minio-go/v7"
	"go.uber.org/zap"

	"github.com/AnathanWang/andexevents/services/upload-service/internal/storage"
)

type UploadsHandler struct {
	logger *zap.Logger
	minio  *storage.MinioClient
}

func NewUploadsHandler(logger *zap.Logger, minioClient *storage.MinioClient) *UploadsHandler {
	return &UploadsHandler{logger: logger, minio: minioClient}
}

var (
	userIDRe   = regexp.MustCompile(`^[a-zA-Z0-9\-_]+$`)
	filenameRe = regexp.MustCompile(`^[a-zA-Z0-9\-_.]+$`)
)

func (h *UploadsHandler) GetUpload(c *gin.Context) {
	bucket := strings.ToLower(strings.TrimSpace(c.Param("bucket")))
	userID := c.Param("userId")
	filename := c.Param("filename")

	if !storage.AllowedBucket(bucket) {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid file path"})
		return
	}
	if !userIDRe.MatchString(userID) || !filenameRe.MatchString(filename) {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid file path"})
		return
	}

	objectName := userID + "/" + filename

	info, err := h.minio.StatObject(c.Request.Context(), bucket, objectName)
	if err != nil {
		errResp := minio.ToErrorResponse(err)
		if errResp.Code == "NoSuchKey" || errResp.Code == "NoSuchObject" {
			c.Status(http.StatusNotFound)
			return
		}
		h.logger.Warn("Failed to stat object", zap.String("bucket", bucket), zap.String("object", objectName), zap.Error(err))
		c.Status(http.StatusNotFound)
		return
	}

	obj, err := h.minio.GetObject(c.Request.Context(), bucket, objectName)
	if err != nil {
		c.Status(http.StatusNotFound)
		return
	}
	defer obj.Close()

	contentType := info.ContentType
	if contentType == "" {
		contentType = "application/octet-stream"
	}

	c.Header("Content-Type", contentType)
	if info.ETag != "" {
		c.Header("ETag", info.ETag)
	}
	c.Header("Cache-Control", "public, max-age=86400")

	c.DataFromReader(http.StatusOK, info.Size, contentType, obj, nil)
}
