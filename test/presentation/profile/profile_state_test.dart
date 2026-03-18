import 'package:flutter_test/flutter_test.dart';
import 'package:andexevents/presentation/profile/bloc/profile_event.dart';
import 'package:andexevents/presentation/profile/bloc/profile_state.dart';
import 'package:andexevents/data/models/user_model.dart';

void main() {
  final sampleUser = UserModel.fromJson(const {
    'id': 'u-1',
    'supabaseUid': 'sub-1',
    'email': 'test@example.com',
    'displayName': 'Test User',
    'gender': 'male',
    'age': 25,
    'interests': ['music', 'travel'],
    'bio': 'hello',
    'photoUrl': '',
    'isOnboardingCompleted': true,
    'createdAt': '2025-01-01T00:00:00.000Z',
    'updatedAt': '2025-01-01T00:00:00.000Z',
  });

  group('ProfileEvent equality', () {
    test('ProfileLoadRequested instances are equal', () {
      expect(
        const ProfileLoadRequested(),
        equals(const ProfileLoadRequested()),
      );
    });

    test('ProfileUpdateRequested with same data are equal', () {
      expect(
        const ProfileUpdateRequested(displayName: 'A', bio: 'B'),
        equals(const ProfileUpdateRequested(displayName: 'A', bio: 'B')),
      );
    });

    test('ProfileUpdateRequested with different data are not equal', () {
      expect(
        const ProfileUpdateRequested(displayName: 'A'),
        isNot(equals(const ProfileUpdateRequested(displayName: 'B'))),
      );
    });

    test('ProfilePhotoUpdateRequested equality', () {
      expect(
        const ProfilePhotoUpdateRequested('/img.jpg'),
        equals(const ProfilePhotoUpdateRequested('/img.jpg')),
      );
      expect(
        const ProfilePhotoUpdateRequested('/a.jpg'),
        isNot(equals(const ProfilePhotoUpdateRequested('/b.jpg'))),
      );
    });

    test('ProfileUpdateRequested props include all optional fields', () {
      const event = ProfileUpdateRequested(
        displayName: 'N',
        bio: 'B',
        interests: ['a'],
        photoUrl: 'url',
        photos: ['p1'],
        socialLinks: {'vk': 'link'},
      );
      expect(event.props.length, 6);
    });
  });

  group('ProfileState equality', () {
    test('ProfileInitial instances are equal', () {
      expect(const ProfileInitial(), equals(const ProfileInitial()));
    });

    test('ProfileLoading instances are equal', () {
      expect(const ProfileLoading(), equals(const ProfileLoading()));
    });

    test('ProfileLoaded with same user/events are equal', () {
      final state1 = ProfileLoaded(sampleUser, userEvents: const []);
      final state2 = ProfileLoaded(sampleUser, userEvents: const []);
      expect(state1, equals(state2));
    });

    test('ProfileLoaded with different users are not equal', () {
      final otherUser = UserModel.fromJson(const {
        'id': 'u-2',
        'supabaseUid': 'sub-2',
        'email': 'other@example.com',
        'displayName': 'Other',
        'gender': 'female',
        'age': 22,
        'interests': [],
        'bio': '',
        'photoUrl': '',
        'isOnboardingCompleted': true,
        'createdAt': '2025-01-01T00:00:00.000Z',
        'updatedAt': '2025-01-01T00:00:00.000Z',
      });
      final state1 = ProfileLoaded(sampleUser, userEvents: const []);
      final state2 = ProfileLoaded(otherUser, userEvents: const []);
      expect(state1, isNot(equals(state2)));
    });

    test('ProfileError with same message are equal', () {
      expect(
        const ProfileError('error'),
        equals(const ProfileError('error')),
      );
    });

    test('ProfileError with different messages are not equal', () {
      expect(
        const ProfileError('a'),
        isNot(equals(const ProfileError('b'))),
      );
    });

    test('ProfileError can carry user for fallback', () {
      final state = ProfileError('err', user: sampleUser);
      expect(state.user, isNotNull);
      expect(state.user!.id, 'u-1');
    });

    test('different state types are not equal', () {
      expect(const ProfileInitial(), isNot(equals(const ProfileLoading())));
      expect(const ProfileLoading(), isNot(equals(const ProfileError('e'))));
    });
  });
}
