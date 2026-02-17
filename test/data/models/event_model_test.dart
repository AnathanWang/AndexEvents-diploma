import 'package:flutter_test/flutter_test.dart';
import 'package:andexevents/data/models/event_model.dart';

void main() {
  group('EventModel', () {
    final now = DateTime(2025, 6, 15, 18, 0, 0);
    final sampleJson = {
      'id': 'evt-123',
      'title': 'Flutter Meetup',
      'description': 'A meetup for Flutter developers',
      'category': 'TECHNOLOGY',
      'location': 'Moscow, Red Square',
      'latitude': 55.7539,
      'longitude': 37.6208,
      'dateTime': now.toIso8601String(),
      'endDateTime': now.add(const Duration(hours: 3)).toIso8601String(),
      'price': 0.0,
      'imageUrl': 'https://example.com/event.jpg',
      'isOnline': false,
      'status': 'APPROVED',
      'rejectionReason': null,
      'maxParticipants': 50,
      'minAge': 18,
      'maxAge': null,
      'createdById': 'user-1',
      'createdAt': now.toIso8601String(),
      'updatedAt': now.toIso8601String(),
      'createdBy': {
        'displayName': 'Organizer',
        'photoUrl': 'https://example.com/avatar.jpg',
      },
      '_count': {'participants': 15},
      'isParticipating': true,
      'participants': [
        {
          'id': 'p-1',
          'userId': 'user-2',
          'eventId': 'evt-123',
          'status': 'GOING',
          'joinedAt': now.toIso8601String(),
          'updatedAt': now.toIso8601String(),
          'user': {
            'id': 'user-2',
            'displayName': 'Participant 1',
            'photoUrl': null,
            'email': 'p1@test.com',
          },
        }
      ],
    };

    test('fromJson parses all fields correctly', () {
      final event = EventModel.fromJson(sampleJson);

      expect(event.id, 'evt-123');
      expect(event.title, 'Flutter Meetup');
      expect(event.description, 'A meetup for Flutter developers');
      expect(event.category, 'TECHNOLOGY');
      expect(event.location, 'Moscow, Red Square');
      expect(event.latitude, 55.7539);
      expect(event.longitude, 37.6208);
      expect(event.dateTime, now);
      expect(event.endDateTime, now.add(const Duration(hours: 3)));
      expect(event.price, 0.0);
      expect(event.imageUrl, 'https://example.com/event.jpg');
      expect(event.isOnline, false);
      expect(event.status, 'APPROVED');
      expect(event.maxParticipants, 50);
      expect(event.minAge, 18);
      expect(event.maxAge, isNull);
      expect(event.createdById, 'user-1');
    });

    test('fromJson extracts creator information from createdBy', () {
      final event = EventModel.fromJson(sampleJson);

      expect(event.creatorName, 'Organizer');
      expect(event.creatorPhotoUrl, 'https://example.com/avatar.jpg');
    });

    test('fromJson extracts participants count from _count object', () {
      final event = EventModel.fromJson(sampleJson);
      expect(event.participantsCount, 15);
    });

    test('fromJson falls back to participantsCount field', () {
      final json = Map<String, dynamic>.from(sampleJson);
      json.remove('_count');
      json['participantsCount'] = 8;

      final event = EventModel.fromJson(json);
      expect(event.participantsCount, 8);
    });

    test('fromJson defaults participantsCount to 0', () {
      final json = Map<String, dynamic>.from(sampleJson);
      json.remove('_count');
      json.remove('participantsCount');

      final event = EventModel.fromJson(json);
      expect(event.participantsCount, 0);
    });

    test('fromJson parses isParticipating', () {
      final event = EventModel.fromJson(sampleJson);
      expect(event.isParticipating, true);
    });

    test('fromJson defaults isParticipating to false when null', () {
      final json = Map<String, dynamic>.from(sampleJson);
      json.remove('isParticipating');

      final event = EventModel.fromJson(json);
      expect(event.isParticipating, false);
    });

    test('fromJson parses preview participants', () {
      final event = EventModel.fromJson(sampleJson);
      expect(event.previewParticipants.length, 1);
      expect(event.previewParticipants.first.user.displayName, 'Participant 1');
    });

    test('fromJson handles null endDateTime', () {
      final json = Map<String, dynamic>.from(sampleJson);
      json['endDateTime'] = null;

      final event = EventModel.fromJson(json);
      expect(event.endDateTime, isNull);
    });

    test('fromJson handles missing createdBy', () {
      final json = Map<String, dynamic>.from(sampleJson);
      json.remove('createdBy');

      final event = EventModel.fromJson(json);
      expect(event.creatorName, isNull);
      expect(event.creatorPhotoUrl, isNull);
    });

    test('toJson produces correct map', () {
      final event = EventModel.fromJson(sampleJson);
      final json = event.toJson();

      expect(json['id'], 'evt-123');
      expect(json['title'], 'Flutter Meetup');
      expect(json['latitude'], 55.7539);
      expect(json['longitude'], 37.6208);
      expect(json['isOnline'], false);
      expect(json['status'], 'APPROVED');
    });

    test('copyWith creates modified copy', () {
      final event = EventModel.fromJson(sampleJson);
      final modified = event.copyWith(
        title: 'Updated Meetup',
        price: 100.0,
        isParticipating: false,
      );

      expect(modified.title, 'Updated Meetup');
      expect(modified.price, 100.0);
      expect(modified.isParticipating, false);
      // Unchanged
      expect(modified.id, event.id);
      expect(modified.category, event.category);
      expect(modified.location, event.location);
    });

    test('fromJson handles integer price as num', () {
      final json = Map<String, dynamic>.from(sampleJson);
      json['price'] = 500; // int, not double

      final event = EventModel.fromJson(json);
      expect(event.price, 500.0);
    });
  });
}
