import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:andexevents/data/models/event_model.dart';
import 'package:andexevents/data/models/user_model.dart';
import 'package:andexevents/data/services/event_service.dart';
import 'package:andexevents/presentation/profile/screens/user_profile_screen.dart';

class _FakeEventService extends EventService {
  _FakeEventService({
    required this.creatorEvents,
    required this.participatedEvents,
  });

  final List<EventModel> creatorEvents;
  final List<EventModel> participatedEvents;

  @override
  Future<List<EventModel>> getUserEvents(String userId) async {
    return creatorEvents;
  }

  @override
  Future<List<EventModel>> getUserParticipatedEvents(String userId) async {
    return participatedEvents;
  }
}

EventModel _event(String id, String title, DateTime dateTime) {
  return EventModel(
    id: id,
    title: title,
    description: 'desc',
    category: 'category',
    location: 'location',
    latitude: 0,
    longitude: 0,
    dateTime: dateTime,
    price: 0,
    isOnline: false,
    status: 'APPROVED',
  );
}

void main() {
  testWidgets('shows real recent events sections for other user profile', (
    WidgetTester tester,
  ) async {
    final user = UserModel(
      id: 'u2',
      firebaseUid: 'fb-u2',
      email: 'u2@example.com',
      displayName: 'Bob',
      isOnboardingCompleted: true,
    );

    final service = _FakeEventService(
      creatorEvents: <EventModel>[
        _event('c1', 'Создал событие 1', DateTime(2026, 3, 1)),
      ],
      participatedEvents: <EventModel>[
        _event('p1', 'Участвовал в событии 1', DateTime(2026, 3, 2)),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: UserProfileScreen.fromUser(
          user: user,
          eventService: service,
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('События как создатель'), findsOneWidget);
    expect(find.text('События, в которых участвовал'), findsOneWidget);
    expect(find.text('Создал событие 1'), findsOneWidget);
    expect(find.text('Участвовал в событии 1'), findsOneWidget);
  });
}
