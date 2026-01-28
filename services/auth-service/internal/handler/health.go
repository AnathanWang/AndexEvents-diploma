package handler

import (
	"github.com/gin-gonic/gin"

	"github.com/AnathanWang/andexevents/shared/pkg/response"
)

// HealthHandler handler для health check
type HealthHandler struct {
	serviceName string
	version     string
}

// NewHealthHandler создаёт новый handler
func NewHealthHandler(serviceName, version string) *HealthHandler {
	return &HealthHandler{
		serviceName: serviceName,
		version:     version,
	}
}

// HealthResponse ответ health check
type HealthResponse struct {
	Status  string `json:"status"`
	Service string `json:"service"`
	Version string `json:"version"`
}

// Health возвращает статус сервиса
func (h *HealthHandler) Health(c *gin.Context) {
	response.Success(c, HealthResponse{
		Status:  "ok",
		Service: h.serviceName,
		Version: h.version,
	})
}

// Ready проверяет готовность сервиса
func (h *HealthHandler) Ready(c *gin.Context) {
	// TODO: проверить БД, Redis и т.д.
	response.Success(c, HealthResponse{
		Status:  "ready",
		Service: h.serviceName,
		Version: h.version,
	})
}
