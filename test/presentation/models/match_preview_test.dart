import 'package:flutter_test/flutter_test.dart';
import 'package:andexevents/presentation/models/match_preview.dart';
import 'package:andexevents/data/models/user_model.dart';

void main() {
  final now = DateTime(2025, 6, 15, 12, 0, 0);

  UserModel makeUser({
    String id = 'u-1',
    String email = 'test@example.com',
    String? displayName = 'Test User',
    int? age = 25,
    String? gender = 'male',
    String? photoUrl,
    List<String> photos = const [],
    String? bio,
    List<String> interests = const [],
    double? lastLatitude,
    double? lastLongitude,
  }) {
    return UserModel.fromJson({
      'id': id,
      'supabaseUid': 'sb-$id',
      'email': email,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'photos': photos,
      'bio': bio,
      'interests': interests,
      'age': age,
      'gender': gender,
      'lastLatitude': lastLatitude,
      'lastLongitude': lastLongitude,
      'isOnboardingCompleted': true,
      'createdAt': now.toIso8601String(),
      'updatedAt': now.toIso8601String(),
    });
  }

  group('MatchPreview.fromUserModel', () {
    test('basic fields are mapped', () {
      final user = makeUser(
        id: 'u-123',
        displayName: 'John',
        age: 30,
        gender: 'male',
        bio: 'Hello',
        interests: ['music', 'sports'],
        lastLatitude: 55.75,
        lastLongitude: 37.61,
      );

      final preview = MatchPreview.fromUserModel(user);

      expect(preview.id, 'u-123');
      expect(preview.name, 'John');
      expect(preview.age, 30);
      expect(preview.gender, 'male');
      expect(preview.bio, 'Hello');
      expect(preview.interests, ['music', 'sports']);
      expect(preview.latitude, 55.75);
      expect(preview.longitude, 37.61);
      expect(preview.userModel, user);
    });

    test('uses email prefix when displayName is null', () {
      final user = makeUser(
        displayName: null,
        email: 'john@example.com',
      );

      final preview = MatchPreview.fromUserModel(user);
      expect(preview.name, 'john');
    });

    test('uses email prefix when displayName is empty', () {
      final user = makeUser(
        displayName: '',
        email: 'john@example.com',
      );

      final preview = MatchPreview.fromUserModel(user);
      expect(preview.name, 'john');
    });

    test('bio defaults to "Нет описания" when null', () {
      final user = makeUser(bio: null);
      final preview = MatchPreview.fromUserModel(user);
      expect(preview.bio, 'Нет описания');
    });
  });

  group('Match percentage (Jaccard similarity)', () {
    test('returns 50 when both interest lists are empty', () {
      final user = makeUser(interests: []);
      final preview = MatchPreview.fromUserModel(
        user,
        currentUserInterests: [],
      );
      expect(preview.matchPercentage, 50);
    });

    test('returns 50 when current user has no interests', () {
      final user = makeUser(interests: ['music']);
      final preview = MatchPreview.fromUserModel(
        user,
        currentUserInterests: [],
      );
      expect(preview.matchPercentage, 50);
    });

    test('returns 100 when interests are identical', () {
      final user = makeUser(interests: ['music', 'sports']);
      final preview = MatchPreview.fromUserModel(
        user,
        currentUserInterests: ['music', 'sports'],
      );
      expect(preview.matchPercentage, 100);
    });

    test('returns value between 50 and 100 for partial overlap', () {
      final user = makeUser(interests: ['music', 'sports', 'travel']);
      final preview = MatchPreview.fromUserModel(
        user,
        currentUserInterests: ['music', 'coding'],
      );
      // intersection = {music}, union = {music, sports, travel, coding} = 4
      // similarity = 1/4 = 0.25, percent = 50 + 0.25*50 = 62.5 -> 63
      expect(preview.matchPercentage, 63);
    });

    test('case insensitive matching', () {
      final user = makeUser(interests: ['Music', 'SPORTS']);
      final preview = MatchPreview.fromUserModel(
        user,
        currentUserInterests: ['music', 'sports'],
      );
      expect(preview.matchPercentage, 100);
    });

    test('trims whitespace in interests', () {
      final user = makeUser(interests: [' music ', '  sports  ']);
      final preview = MatchPreview.fromUserModel(
        user,
        currentUserInterests: ['music', 'sports'],
      );
      expect(preview.matchPercentage, 100);
    });

    test('ignores empty string interests', () {
      final user = makeUser(interests: ['music', '', '  ']);
      final preview = MatchPreview.fromUserModel(
        user,
        currentUserInterests: ['music'],
      );
      expect(preview.matchPercentage, 100);
    });
  });

  group('Common interests', () {
    test('returns empty when no overlap', () {
      final user = makeUser(interests: ['music']);
      final preview = MatchPreview.fromUserModel(
        user,
        currentUserInterests: ['sports'],
      );
      expect(preview.commonInterests, isEmpty);
    });

    test('returns overlapping interests', () {
      final user = makeUser(interests: ['music', 'sports', 'travel']);
      final preview = MatchPreview.fromUserModel(
        user,
        currentUserInterests: ['sports', 'music', 'coding'],
      );
      expect(preview.commonInterests, containsAll(['music', 'sports']));
      expect(preview.commonInterests.length, 2);
    });

    test('limited to 3 common interests', () {
      final user = makeUser(interests: ['a', 'b', 'c', 'd', 'e']);
      final preview = MatchPreview.fromUserModel(
        user,
        currentUserInterests: ['a', 'b', 'c', 'd', 'e'],
      );
      expect(preview.commonInterests.length, 3);
    });

    test('sorted alphabetically', () {
      final user = makeUser(interests: ['travel', 'music', 'art']);
      final preview = MatchPreview.fromUserModel(
        user,
        currentUserInterests: ['travel', 'music', 'art'],
      );
      expect(preview.commonInterests, ['art', 'music', 'travel']);
    });
  });

  group('subtitle', () {
    test('shows age and gender for male', () {
      final user = makeUser(age: 25, gender: 'male');
      final preview = MatchPreview.fromUserModel(user);
      expect(preview.subtitle, '25 лет, М');
    });

    test('shows age and gender for female', () {
      final user = makeUser(age: 22, gender: 'female');
      final preview = MatchPreview.fromUserModel(user);
      expect(preview.subtitle, '22 лет, Ж');
    });

    test('shows only age when gender is null', () {
      final user = makeUser(age: 25, gender: null);
      final preview = MatchPreview.fromUserModel(user);
      expect(preview.subtitle, '25 лет');
    });

    test('shows only gender when age is null', () {
      final user = makeUser(age: null, gender: 'male');
      final preview = MatchPreview.fromUserModel(user);
      expect(preview.subtitle, 'М');
    });

    test('shows "Пользователь" when both are null', () {
      final user = makeUser(age: null, gender: null);
      final preview = MatchPreview.fromUserModel(user);
      expect(preview.subtitle, 'Пользователь');
    });
  });

  group('avatar', () {
    test('returns photoUrl when available', () {
      final user = makeUser(
        photoUrl: 'https://example.com/photo.jpg',
        photos: ['other.jpg'],
      );
      final preview = MatchPreview.fromUserModel(user);
      expect(preview.avatar, 'https://example.com/photo.jpg');
    });

    test('returns first photo when photoUrl is null', () {
      final user = makeUser(
        photoUrl: null,
        photos: ['first.jpg', 'second.jpg'],
      );
      final preview = MatchPreview.fromUserModel(user);
      expect(preview.avatar, 'first.jpg');
    });

    test('returns null when no photos', () {
      final user = makeUser(photoUrl: null, photos: []);
      final preview = MatchPreview.fromUserModel(user);
      expect(preview.avatar, isNull);
    });
  });
}
