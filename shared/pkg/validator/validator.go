// Package validator предоставляет валидацию запросов.
//
// go-playground/validator - стандартный валидатор для Go.
// Поддерживает теги в структурах: `validate:"required,email,min=3"`
package validator

import (
	"github.com/go-playground/validator/v10"
)

var validate *validator.Validate

func init() {
	validate = validator.New()

	// Регистрируем кастомные валидаторы
	_ = validate.RegisterValidation("gender", validateGender)
	_ = validate.RegisterValidation("latitude", validateLatitude)
	_ = validate.RegisterValidation("longitude", validateLongitude)
}

// Validate валидирует структуру
func Validate(s interface{}) error {
	return validate.Struct(s)
}

// validateGender проверяет допустимые значения пола
func validateGender(fl validator.FieldLevel) bool {
	gender := fl.Field().String()
	return gender == "" || gender == "male" || gender == "female" || gender == "other"
}

// validateLatitude проверяет широту (-90 до 90)
func validateLatitude(fl validator.FieldLevel) bool {
	lat := fl.Field().Float()
	return lat >= -90 && lat <= 90
}

// validateLongitude проверяет долготу (-180 до 180)
func validateLongitude(fl validator.FieldLevel) bool {
	lng := fl.Field().Float()
	return lng >= -180 && lng <= 180
}
