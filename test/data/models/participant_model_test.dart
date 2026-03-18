import 'package:flutter_test/flutter_test.dart';
import 'package:andexevents/data/models/participant_model.dart';

void main() {
  final now = DateTime(2025, 6, 15, 18, 0, 0);

  group('UserInfo', () {
    test('fromJson parses all fields', () {
      final info = UserInfo.fromJson({
        'id': 'u-1',
        'displayName': 'John',
        'photoUrl': 'https://example.com/photo.jpg',
        'email': 'john@test.com',
      });

      expect(info.id, 'u-1');
      expect(info.displayName, 'John');
      expect(info.photoUrl, 'https://example.com/photo.jpg');
      expect(info.email, 'john@test.com');
    });

    test('displayName defaults to "Unknown" when null', () {
      final info = UserInfo.fromJson({
        'id': 'u-1',
        'displayName': null,
      });
      expect(info.displayName, 'Unknown');
    });

    test('optional fields are null when missing', () {
      final info = UserInfo.fromJson({
        'id': 'u-1',
        'displayName': 'John',
      });
      expect(info.photoUrl, isNull);
      expect(info.email, isNull);
    });
  });

  group('ParticipantModel', () {
    test('fromJson parses all fields correctly', () {
      final participant = ParticipantModel.fromJson({
        'id': 'p-1',
        'userId': 'u-1',
        'eventId': 'evt-1',
        'status': 'GOING',
        'joinedAt': now.toIso8601String(),
        'updatedAt': now.toIso8601String(),
        'user': {
          'id': 'u-1',
          'displayName': 'John',
          'photoUrl': null,
          'email': 'john@test.com',
        },
      });

      expect(participant.id, 'p-1');
      expect(participant.userId, 'u-1');
      expect(participant.eventId, 'evt-1');
      expect(participant.status, 'GOING');
      expect(participant.joinedAt, now);
      expect(participant.updatedAt, now);
      expect(participant.user.id, 'u-1');
      expect(participant.user.displayName, 'John');
    });

    test('fromJson with INTERESTED status', () {
      final participant = ParticipantModel.fromJson({
        'id': 'p-2',
        'userId': 'u-2',
        'eventId': 'evt-2',
        'status': 'INTERESTED',
        'joinedAt': now.toIso8601String(),
        'updatedAt': now.toIso8601String(),
        'user': {
          'id': 'u-2',
          'displayName': 'Jane',
        },
      });

      expect(participant.status, 'INTERESTED');
      expect(participant.user.displayName, 'Jane');
    });

    test('fromJson with MAYBE status', () {
      final participant = ParticipantModel.fromJson({
        'id': 'p-3',
        'userId': 'u-3',
        'eventId': 'evt-3',
        'status': 'MAYBE',
        'joinedAt': now.toIso8601String(),
        'updatedAt': now.toIso8601String(),
        'user': {
          'id': 'u-3',
          'displayName': 'Bob',
        },
      });

      expect(participant.status, 'MAYBE');
    });
  });
}
