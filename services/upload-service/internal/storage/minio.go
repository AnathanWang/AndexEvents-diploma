package storage

import (
	"context"
	"fmt"
	"io"
	"net/http"
	"strings"

	"github.com/minio/minio-go/v7"
	"github.com/minio/minio-go/v7/pkg/credentials"

	"github.com/AnathanWang/andexevents/services/upload-service/internal/config"
)

type MinioClient struct {
	client *minio.Client
}

type PutResult struct {
	ETag string
	Size int64
}

func NewMinioClient(cfg *config.Config) (*MinioClient, error) {
	client, err := minio.New(cfg.MinioEndpoint, &minio.Options{
		Creds:     credentials.NewStaticV4(cfg.MinioAccessKey, cfg.MinioSecretKey, ""),
		Secure:    cfg.MinioUseSSL,
		Transport: http.DefaultTransport,
	})
	if err != nil {
		return nil, fmt.Errorf("minio new: %w", err)
	}

	return &MinioClient{client: client}, nil
}

func (m *MinioClient) PutObject(ctx context.Context, bucket string, objectName string, reader io.Reader, size int64, contentType string) (*PutResult, error) {
	options := minio.PutObjectOptions{ContentType: contentType}
	info, err := m.client.PutObject(ctx, bucket, objectName, reader, size, options)
	if err != nil {
		return nil, err
	}
	return &PutResult{ETag: info.ETag, Size: info.Size}, nil
}

func (m *MinioClient) GetObject(ctx context.Context, bucket string, objectName string) (*minio.Object, error) {
	return m.client.GetObject(ctx, bucket, objectName, minio.GetObjectOptions{})
}

func (m *MinioClient) StatObject(ctx context.Context, bucket string, objectName string) (minio.ObjectInfo, error) {
	return m.client.StatObject(ctx, bucket, objectName, minio.StatObjectOptions{})
}

func AllowedBucket(bucket string) bool {
	switch bucket {
	case "avatars", "events":
		return true
	default:
		return false
	}
}

func GuessContentType(filename string, sniff []byte, headerContentType string) string {
	ct := strings.TrimSpace(strings.ToLower(headerContentType))
	if strings.HasPrefix(ct, "image/") {
		return ct
	}
	if len(sniff) > 0 {
		return http.DetectContentType(sniff)
	}

	lower := strings.ToLower(filename)
	if strings.HasSuffix(lower, ".jpg") || strings.HasSuffix(lower, ".jpeg") {
		return "image/jpeg"
	}
	if strings.HasSuffix(lower, ".png") {
		return "image/png"
	}
	if strings.HasSuffix(lower, ".gif") {
		return "image/gif"
	}
	if strings.HasSuffix(lower, ".webp") {
		return "image/webp"
	}
	return "application/octet-stream"
}
