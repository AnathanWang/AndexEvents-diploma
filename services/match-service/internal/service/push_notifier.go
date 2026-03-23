package service

import (
	"context"
	"fmt"
	"strings"

	"github.com/AnathanWang/andexevents/services/match-service/internal/model"
)

type PushNotifier interface {
	NotifyIncomingLike(ctx context.Context, fromUser, toUser model.User, action model.MatchAction) error
}

type FirebasePushClient interface {
	SendPushNotification(ctx context.Context, token, title, body string, data map[string]string) error
}

type noopNotifier struct{}

func (noopNotifier) NotifyIncomingLike(context.Context, model.User, model.User, model.MatchAction) error {
	return nil
}

type fcmPushNotifier struct {
	client FirebasePushClient
}

func NewFCMPushNotifier(client FirebasePushClient) PushNotifier {
	if client == nil {
		return noopNotifier{}
	}

	return &fcmPushNotifier{client: client}
}

func (n *fcmPushNotifier) NotifyIncomingLike(ctx context.Context, fromUser, toUser model.User, action model.MatchAction) error {
	if n == nil || n.client == nil {
		return nil
	}

	token := ""
	if toUser.FCMToken != nil {
		token = strings.TrimSpace(*toUser.FCMToken)
	}
	if token == "" {
		return nil
	}

	name := "Someone"
	if fromUser.DisplayName != nil {
		displayName := strings.TrimSpace(*fromUser.DisplayName)
		if displayName != "" {
			name = displayName
		}
	}

	title := "New like"
	body := fmt.Sprintf("%s liked your profile", name)
	notificationType := "incoming_like"
	if action == model.MatchActionSuperLike {
		title = "New super like"
		body = fmt.Sprintf("%s sent you a super like", name)
		notificationType = "incoming_super_like"
	}

	data := map[string]string{
		"type":       notificationType,
		"fromUserId": fromUser.ID,
		"toUserId":   toUser.ID,
	}

	return n.client.SendPushNotification(ctx, token, title, body, data)
}
