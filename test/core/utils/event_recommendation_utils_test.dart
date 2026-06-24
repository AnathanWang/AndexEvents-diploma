import 'package:flutter_test/flutter_test.dart';
import 'package:andexevents/core/utils/event_recommendation_utils.dart';
import 'package:andexevents/data/models/event_model.dart';
import 'package:andexevents/data/models/user_model.dart';

void main() {
  final eventStart = DateTime.now().add(const Duration(days: 3));

  UserModel user({
    List<String> interests = const <String>[],
    double? lat,
    double? lon,
  }) {
    return UserModel.fromJson(<String, dynamic>{
      'id': 'u1',
      'supabaseUid': 'sb-u1',
      'email': 'u1@example.com',
      'interests': interests,
      'lastLatitude': lat,
      'lastLongitude': lon,
      'isOnboardingCompleted': true,
      'createdAt': eventStart.toIso8601String(),
      'updatedAt': eventStart.toIso8601String(),
    });
  }

  EventModel event({
    required String id,
    String category = 'other',
    double lat = 55.75,
    double lon = 37.62,
    int participants = 0,
    bool participating = false,
  }) {
    return EventModel.fromJson(<String, dynamic>{
      'id': id,
      'title': 'Event $id',
      'description': 'desc',
      'category': category,
      'location': 'Moscow',
      'latitude': lat,
      'longitude': lon,
      'dateTime': eventStart.toIso8601String(),
      'price': 0,
      'isOnline': false,
      'status': 'APPROVED',
      'participantsCount': participants,
      'isParticipating': participating,
    });
  }

  test('prefers events matching user interests', () {
    final profile = EventRecommendationUtils.buildProfile(
      user: user(interests: const <String>['Музыка', 'Спорт']),
    );

    final concert = event(id: 'c', category: 'concert');
    final cinema = event(id: 'm', category: 'cinema');

    final concertScore = EventRecommendationUtils.scoreEvent(
      event: concert,
      profile: profile,
    );
    final cinemaScore = EventRecommendationUtils.scoreEvent(
      event: cinema,
      profile: profile,
    );

    expect(concertScore, greaterThan(cinemaScore));
  });

  test('sortEvents ranks closer and more relevant events higher', () {
    final profile = EventRecommendationUtils.buildProfile(
      user: user(
        interests: const <String>['Спорт'],
        lat: 55.75,
        lon: 37.62,
      ),
      participatedEvents: <EventModel>[event(id: 'past', category: 'sport')],
    );

    final ranked = EventRecommendationUtils.sortEvents(
      events: <EventModel>[
        event(id: 'far', category: 'cinema', lat: 59.93, lon: 30.31),
        event(id: 'near', category: 'sport', lat: 55.76, lon: 37.63),
      ],
      profile: profile,
      originLatitude: 55.75,
      originLongitude: 37.62,
    );

    expect(ranked.first.id, 'near');
  });

  test('recommendedEvents skips events user already joined', () {
    final profile = EventRecommendationUtils.buildProfile(
      user: user(interests: const <String>['Кино']),
    );

    final picks = EventRecommendationUtils.recommendedEvents(
      events: <EventModel>[
        event(id: 'joined', category: 'cinema', participating: true),
        event(id: 'open', category: 'cinema'),
      ],
      profile: profile,
      limit: 5,
      minScore: 0,
    );

    expect(picks.any((event) => event.id == 'joined'), isFalse);
    expect(picks.first.id, 'open');
  });
}
