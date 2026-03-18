import 'package:flutter_test/flutter_test.dart';
import 'package:andexevents/data/models/user_model.dart';

void main() {
  group('UserModel', () {
    final now = DateTime(2025, 1, 15, 12, 0, 0);
    final sampleJson = {
      'id': 'user-123',
      'supabaseUid': 'sb-uid-456',
      'email': 'test@example.com',
      'displayName': 'Test User',
      'photoUrl': 'https://example.com/photo.jpg',
      'photos': ['photo1.jpg', 'photo2.jpg'],
      'bio': 'Hello world',
      'interests': ['music', 'sports', 'travel'],
      'socialLinks': {'telegram': '@testuser'},
      'age': 25,
      'gender': 'male',
      'lastLatitude': 55.7558,
      'lastLongitude': 37.6173,
      'isOnboardingCompleted': true,
      'createdAt': now.toIso8601String(),
      'updatedAt': now.toIso8601String(),
    };

    test('fromJson parses all fields correctly', () {
      final user = UserModel.fromJson(sampleJson);

      expect(user.id, 'user-123');
      expect(user.supabaseUid, 'sb-uid-456');
      expect(user.email, 'test@example.com');
      expect(user.displayName, 'Test User');
      expect(user.photoUrl, 'https://example.com/photo.jpg');
      expect(user.photos, ['photo1.jpg', 'photo2.jpg']);
      expect(user.bio, 'Hello world');
      expect(user.interests, ['music', 'sports', 'travel']);
      expect(user.socialLinks, {'telegram': '@testuser'});
      expect(user.age, 25);
      expect(user.gender, 'male');
      expect(user.lastLatitude, 55.7558);
      expect(user.lastLongitude, 37.6173);
      expect(user.isOnboardingCompleted, true);
      expect(user.createdAt, now);
      expect(user.updatedAt, now);
    });

    test('fromJson handles null optional fields', () {
      final minimalJson = {
        'id': 'user-1',
        'supabaseUid': 'sb-1',
        'email': 'min@test.com',
        'createdAt': now.toIso8601String(),
        'updatedAt': now.toIso8601String(),
      };

      final user = UserModel.fromJson(minimalJson);

      expect(user.displayName, isNull);
      expect(user.photoUrl, isNull);
      expect(user.photos, isEmpty);
      expect(user.bio, isNull);
      expect(user.interests, isEmpty);
      expect(user.socialLinks, isNull);
      expect(user.age, isNull);
      expect(user.gender, isNull);
      expect(user.lastLatitude, isNull);
      expect(user.lastLongitude, isNull);
      expect(user.isOnboardingCompleted, false);
    });

    test('fromJson defaults isOnboardingCompleted to false when null', () {
      final json = {
        ...sampleJson,
        'isOnboardingCompleted': null,
      };
      final user = UserModel.fromJson(json);
      expect(user.isOnboardingCompleted, false);
    });

    test('toJson produces correct map', () {
      final user = UserModel.fromJson(sampleJson);
      final json = user.toJson();

      expect(json['id'], 'user-123');
      expect(json['email'], 'test@example.com');
      expect(json['displayName'], 'Test User');
      expect(json['photos'], ['photo1.jpg', 'photo2.jpg']);
      expect(json['interests'], ['music', 'sports', 'travel']);
      expect(json['isOnboardingCompleted'], true);
    });

    test('toJson roundtrip preserves data', () {
      final user = UserModel.fromJson(sampleJson);
      final json = user.toJson();
      final restored = UserModel.fromJson(json);

      expect(restored.id, user.id);
      expect(restored.email, user.email);
      expect(restored.displayName, user.displayName);
      expect(restored.bio, user.bio);
      expect(restored.interests, user.interests);
      expect(restored.age, user.age);
    });

    test('copyWith creates modified copy', () {
      final user = UserModel.fromJson(sampleJson);
      final modified = user.copyWith(
        displayName: 'New Name',
        age: 30,
        interests: ['coding'],
      );

      expect(modified.displayName, 'New Name');
      expect(modified.age, 30);
      expect(modified.interests, ['coding']);
      // Unchanged fields
      expect(modified.id, user.id);
      expect(modified.email, user.email);
      expect(modified.bio, user.bio);
    });

    test('copyWith with no changes returns equivalent object', () {
      final user = UserModel.fromJson(sampleJson);
      final copy = user.copyWith();

      expect(copy.id, user.id);
      expect(copy.email, user.email);
      expect(copy.displayName, user.displayName);
      expect(copy.isOnboardingCompleted, user.isOnboardingCompleted);
    });

    test('fromJson handles numeric latitude/longitude as int', () {
      final json = {
        ...sampleJson,
        'lastLatitude': 55, // int instead of double
        'lastLongitude': 37,
      };
      final user = UserModel.fromJson(json);
      expect(user.lastLatitude, 55.0);
      expect(user.lastLongitude, 37.0);
    });
  });
}
