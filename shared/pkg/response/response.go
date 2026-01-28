// Package response предоставляет стандартный формат ответов API.
//
// Зачем единый формат?
// 1. Консистентность - клиент всегда знает структуру ответа
// 2. Упрощает обработку ошибок на клиенте
// 3. Легко добавить метаданные (pagination, etc.)
package response

import (
	"net/http"

	"github.com/gin-gonic/gin"
)

// Response стандартная структура ответа API
type Response struct {
	Success bool        `json:"success"`         // true если запрос успешен
	Data    interface{} `json:"data,omitempty"`  // данные ответа
	Error   *ErrorInfo  `json:"error,omitempty"` // информация об ошибке
	Meta    *Meta       `json:"meta,omitempty"`  // метаданные (пагинация и т.д.)
}

// ErrorInfo информация об ошибке
type ErrorInfo struct {
	Code    string            `json:"code"`              // код ошибки (VALIDATION_ERROR, NOT_FOUND, etc.)
	Message string            `json:"message"`           // человекочитаемое сообщение
	Details map[string]string `json:"details,omitempty"` // детали (для validation errors)
}

// Meta метаданные ответа
type Meta struct {
	Total  int `json:"total,omitempty"`  // всего записей
	Limit  int `json:"limit,omitempty"`  // лимит на страницу
	Offset int `json:"offset,omitempty"` // смещение
}

// Коды ошибок
const (
	CodeValidationError = "VALIDATION_ERROR"
	CodeNotFound        = "NOT_FOUND"
	CodeUnauthorized    = "UNAUTHORIZED"
	CodeForbidden       = "FORBIDDEN"
	CodeConflict        = "CONFLICT"
	CodeInternalError   = "INTERNAL_ERROR"
	CodeBadRequest      = "BAD_REQUEST"
)

// Success возвращает успешный ответ
func Success(c *gin.Context, data interface{}) {
	c.JSON(http.StatusOK, Response{
		Success: true,
		Data:    data,
	})
}

// Created возвращает ответ при создании ресурса (201)
func Created(c *gin.Context, data interface{}) {
	c.JSON(http.StatusCreated, Response{
		Success: true,
		Data:    data,
	})
}

// SuccessWithMeta возвращает успешный ответ с метаданными
func SuccessWithMeta(c *gin.Context, data interface{}, meta *Meta) {
	c.JSON(http.StatusOK, Response{
		Success: true,
		Data:    data,
		Meta:    meta,
	})
}

// BadRequest возвращает ошибку 400
func BadRequest(c *gin.Context, message string) {
	c.JSON(http.StatusBadRequest, Response{
		Success: false,
		Error: &ErrorInfo{
			Code:    CodeBadRequest,
			Message: message,
		},
	})
}

// ValidationError возвращает ошибку валидации с деталями
func ValidationError(c *gin.Context, err error) {
	c.JSON(http.StatusBadRequest, Response{
		Success: false,
		Error: &ErrorInfo{
			Code:    CodeValidationError,
			Message: "Validation failed",
			Details: parseValidationErrors(err),
		},
	})
}

// Unauthorized возвращает ошибку 401
func Unauthorized(c *gin.Context, message string) {
	c.JSON(http.StatusUnauthorized, Response{
		Success: false,
		Error: &ErrorInfo{
			Code:    CodeUnauthorized,
			Message: message,
		},
	})
}

// Forbidden возвращает ошибку 403
func Forbidden(c *gin.Context, message string) {
	c.JSON(http.StatusForbidden, Response{
		Success: false,
		Error: &ErrorInfo{
			Code:    CodeForbidden,
			Message: message,
		},
	})
}

// NotFound возвращает ошибку 404
func NotFound(c *gin.Context, message string) {
	c.JSON(http.StatusNotFound, Response{
		Success: false,
		Error: &ErrorInfo{
			Code:    CodeNotFound,
			Message: message,
		},
	})
}

// Conflict возвращает ошибку 409 (уже существует)
func Conflict(c *gin.Context, message string) {
	c.JSON(http.StatusConflict, Response{
		Success: false,
		Error: &ErrorInfo{
			Code:    CodeConflict,
			Message: message,
		},
	})
}

// InternalError возвращает ошибку 500
func InternalError(c *gin.Context, message string) {
	c.JSON(http.StatusInternalServerError, Response{
		Success: false,
		Error: &ErrorInfo{
			Code:    CodeInternalError,
			Message: message,
		},
	})
}

// parseValidationErrors парсит ошибки валидации в map
func parseValidationErrors(err error) map[string]string {
	details := make(map[string]string)
	// Простая обработка - в реальности нужно парсить validator errors
	details["error"] = err.Error()
	return details
}
