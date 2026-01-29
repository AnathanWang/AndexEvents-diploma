package main

import (
	"context"
	"flag"
	"fmt"
	"io"
	"io/fs"
	"log"
	"os"
	"path/filepath"
	"strings"

	"github.com/AnathanWang/andexevents/services/upload-service/internal/config"
	"github.com/AnathanWang/andexevents/services/upload-service/internal/storage"
)

func main() {
	var (
		srcDir = flag.String("src", "../../backend/public/uploads", "Source directory containing uploads/{bucket}/{userId}/{filename}")
		dryRun = flag.Bool("dry-run", false, "If true, only prints what would be uploaded")
	)
	flag.Parse()

	cfg := config.Load()
	minioClient, err := storage.NewMinioClient(cfg)
	if err != nil {
		log.Fatalf("minio init: %v", err)
	}

	srcAbs, err := filepath.Abs(*srcDir)
	if err != nil {
		log.Fatalf("abs src: %v", err)
	}

	info, err := os.Stat(srcAbs)
	if err != nil {
		log.Fatalf("stat src: %v", err)
	}
	if !info.IsDir() {
		log.Fatalf("src is not a directory: %s", srcAbs)
	}

	log.Printf("[migrate] source=%s dryRun=%v", srcAbs, *dryRun)

	uploaded := 0
	skipped := 0
	failed := 0

	err = filepath.WalkDir(srcAbs, func(path string, d fs.DirEntry, walkErr error) error {
		if walkErr != nil {
			failed++
			log.Printf("[migrate] walk error: %v", walkErr)
			return nil
		}
		if d.IsDir() {
			return nil
		}

		rel, err := filepath.Rel(srcAbs, path)
		if err != nil {
			failed++
			log.Printf("[migrate] rel error: %v", err)
			return nil
		}

		// Expect rel like: avatars/<userId>/<filename>
		parts := strings.Split(filepath.ToSlash(rel), "/")
		if len(parts) < 3 {
			skipped++
			return nil
		}

		bucket := strings.ToLower(strings.TrimSpace(parts[0]))
		userID := parts[1]
		filename := parts[len(parts)-1]

		if !storage.AllowedBucket(bucket) {
			skipped++
			return nil
		}
		if userID == "" || filename == "" {
			skipped++
			return nil
		}

		objectName := userID + "/" + filename

		fileInfo, err := os.Stat(path)
		if err != nil {
			failed++
			log.Printf("[migrate] stat file error: %s: %v", path, err)
			return nil
		}

		if fileInfo.Size() == 0 {
			skipped++
			return nil
		}

		if *dryRun {
			log.Printf("[dry-run] %s -> %s/%s (%d bytes)", rel, bucket, objectName, fileInfo.Size())
			uploaded++
			return nil
		}

		f, err := os.Open(path)
		if err != nil {
			failed++
			log.Printf("[migrate] open error: %s: %v", path, err)
			return nil
		}
		defer f.Close()

		sniff := make([]byte, 512)
		n, _ := io.ReadFull(f, sniff)
		if n < 0 {
			n = 0
		}
		sniff = sniff[:n]
		_, _ = f.Seek(0, 0)

		contentType := storage.GuessContentType(filename, sniff, "")

		_, putErr := minioClient.PutObject(context.Background(), bucket, objectName, f, fileInfo.Size(), contentType)
		if putErr != nil {
			failed++
			log.Printf("[migrate] put error: %s -> %s/%s: %v", rel, bucket, objectName, putErr)
			return nil
		}

		uploaded++
		if uploaded%100 == 0 {
			log.Printf("[migrate] progress uploaded=%d skipped=%d failed=%d", uploaded, skipped, failed)
		}
		return nil
	})
	if err != nil {
		log.Fatalf("walk fatal: %v", err)
	}

	fmt.Printf("\n[migrate] DONE uploaded=%d skipped=%d failed=%d\n", uploaded, skipped, failed)
	if failed > 0 {
		os.Exit(1)
	}
}
