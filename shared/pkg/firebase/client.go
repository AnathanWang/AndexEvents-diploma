// Package firebase предоставляет клиент для Firebase Admin SDK.
//
// Firebase Auth используется для:
// 1. Верификации JWT токенов от мобильного приложения
// 2. Отправки push-уведомлений через FCM
// 3. Получения информации о пользователе
package firebase

import (
	"context"
	"fmt"

	firebase "firebase.google.com/go/v4"
	"firebase.google.com/go/v4/auth"
	"firebase.google.com/go/v4/messaging"
	"google.golang.org/api/option"
)

// Client обёртка над Firebase Admin SDK
type Client struct {
	app       *firebase.App
	auth      *auth.Client
	messaging *messaging.Client
}

// Config конфигурация Firebase
type Config struct {
	CredentialsFile string // Путь к JSON файлу с credentials
	ProjectID       string // Firebase Project ID
}

// NewClient создаёт новый Firebase клиент
func NewClient(ctx context.Context, cfg Config) (*Client, error) {
	var opts []option.ClientOption

	if cfg.CredentialsFile != "" {
		opts = append(opts, option.WithCredentialsFile(cfg.CredentialsFile))
	}

	config := &firebase.Config{
		ProjectID: cfg.ProjectID,
	}

	app, err := firebase.NewApp(ctx, config, opts...)
	if err != nil {
		return nil, fmt.Errorf("failed to initialize firebase app: %w", err)
	}

	authClient, err := app.Auth(ctx)
	if err != nil {
		return nil, fmt.Errorf("failed to get auth client: %w", err)
	}

	msgClient, err := app.Messaging(ctx)
	if err != nil {
		return nil, fmt.Errorf("failed to get messaging client: %w", err)
	}

	return &Client{
		app:       app,
		auth:      authClient,
		messaging: msgClient,
	}, nil
}

// VerifyToken верифицирует Firebase ID токен
// Возвращает информацию о пользователе из токена
func (c *Client) VerifyToken(ctx context.Context, idToken string) (*auth.Token, error) {
	token, err := c.auth.VerifyIDToken(ctx, idToken)
	if err != nil {
		return nil, fmt.Errorf("failed to verify token: %w", err)
	}
	return token, nil
}

// GetUser получает информацию о пользователе по UID
func (c *Client) GetUser(ctx context.Context, uid string) (*auth.UserRecord, error) {
	user, err := c.auth.GetUser(ctx, uid)
	if err != nil {
		return nil, fmt.Errorf("failed to get user: %w", err)
	}
	return user, nil
}

// SendPushNotification отправляет push-уведомление на устройство
func (c *Client) SendPushNotification(ctx context.Context, token, title, body string, data map[string]string) error {
	message := &messaging.Message{
		Token: token,
		Notification: &messaging.Notification{
			Title: title,
			Body:  body,
		},
		Data: data,
		Android: &messaging.AndroidConfig{
			Priority: "high",
		},
		APNS: &messaging.APNSConfig{
			Payload: &messaging.APNSPayload{
				Aps: &messaging.Aps{
					Sound: "default",
				},
			},
		},
	}

	_, err := c.messaging.Send(ctx, message)
	if err != nil {
		return fmt.Errorf("failed to send notification: %w", err)
	}

	return nil
}

// SendMulticast отправляет уведомление нескольким устройствам
func (c *Client) SendMulticast(ctx context.Context, tokens []string, title, body string, data map[string]string) (*messaging.BatchResponse, error) {
	message := &messaging.MulticastMessage{
		Tokens: tokens,
		Notification: &messaging.Notification{
			Title: title,
			Body:  body,
		},
		Data: data,
	}

	response, err := c.messaging.SendEachForMulticast(ctx, message)
	if err != nil {
		return nil, fmt.Errorf("failed to send multicast: %w", err)
	}

	return response, nil
}
