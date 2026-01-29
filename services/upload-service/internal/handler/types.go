package handler

// UploadResponse mirrors the legacy Node upload response.
// success: boolean
// message: string (only on errors)
// fileUrl: string
// file: { name, size, bucket }
type UploadResponse struct {
	Success bool        `json:"success"`
	Message string      `json:"message,omitempty"`
	FileURL string      `json:"fileUrl,omitempty"`
	File    *FileObject `json:"file,omitempty"`
}

type FileObject struct {
	Name   string `json:"name"`
	Size   int64  `json:"size"`
	Bucket string `json:"bucket"`
}
