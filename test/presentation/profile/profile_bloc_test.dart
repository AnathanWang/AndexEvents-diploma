import 'package:flutter_test/flutter_test.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:andexevents/presentation/profile/bloc/profile_bloc.dart';
import 'package:andexevents/presentation/profile/bloc/profile_event.dart';
import 'package:andexevents/presentation/profile/bloc/profile_state.dart';
import 'package:andexevents/data/services/user_service.dart';
import 'package:andexevents/data/services/event_service.dart';
import 'package:andexevents/data/models/user_model.dart';
import 'package:andexevents/data/models/event_model.dart';

class MockUserService extends Mock implements UserService {}

class MockEventService extends Mock implements EventService {}

void main() {
  late MockUserService mockUserService;
  late MockEventService mockEventService;

  final now = DateTime(2025, 6, 15, 12, 0, 0);

  final sampleUser = UserModel.fromJson({
    'id': 'u-1',
    'supabaseUid': 'sb-1',
    'email': 'test@example.com',
    'displayName': 'Test User',
    'interests': ['music', 'sports'],
    'isOnboardingCompleted': true,
    'createdAt': now.toIso8601String(),
    'updatedAt': now.toIso8601String(),
  });

  final sampleEvent = EventModel.fromJson({
    'id': 'evt-1',
    'title': 'User Event',
    'description': 'Desc',
    'category': 'MUSIC',
    'location': 'Moscow',
    'latitude': 55.75,
    'longitude': 37.61,
    'dateTime': now.toIso8601String(),
    'price': 0.0,
    'isOnline': false,
    'status': 'APPROVED',
    'createdById': 'u-1',
    'createdAt': now.toIso8601String(),
    'updatedAt': now.toIso8601String(),
  });

  setUp(() {
    mockUserService = MockUserService();
    mockEventService = MockEventService();
  });

  group('ProfileBloc', () {
    test('initial state is ProfileInitial', () {
      final bloc = ProfileBloc(
        userService: mockUserService,
        eventService: mockEventService,
      );
      expect(bloc.state, const ProfileInitial());
      bloc.close();
    });

    blocTest<ProfileBloc, ProfileState>(
      'emits [ProfileLoading, ProfileLoaded] on ProfileLoadRequested',
      build: () {
        when(() => mockUserService.getCurrentUser())
            .thenAnswer((_) async => sampleUser);
        when(() => mockEventService.getUserEvents('u-1'))
            .thenAnswer((_) async => [sampleEvent]);
        return ProfileBloc(
          userService: mockUserService,
          eventService: mockEventService,
        );
      },
      act: (bloc) => bloc.add(const ProfileLoadRequested()),
      expect: () => [
        const ProfileLoading(),
        isA<ProfileLoaded>()
            .having((s) => s.user.id, 'user.id', 'u-1')
            .having((s) => s.userEvents.length, 'events', 1),
      ],
    );

    blocTest<ProfileBloc, ProfileState>(
      'emits [ProfileLoading, ProfileError] when getCurrentUser throws',
      build: () {
        when(() => mockUserService.getCurrentUser())
            .thenThrow(Exception('no auth'));
        return ProfileBloc(
          userService: mockUserService,
          eventService: mockEventService,
        );
      },
      act: (bloc) => bloc.add(const ProfileLoadRequested()),
      expect: () => [
        const ProfileLoading(),
        isA<ProfileError>(),
      ],
    );

    blocTest<ProfileBloc, ProfileState>(
      'emits [ProfileUpdating, ProfileLoaded] on ProfileUpdateRequested',
      build: () {
        when(() => mockUserService.updateProfile(
              displayName: any(named: 'displayName'),
              photoUrl: any(named: 'photoUrl'),
              photos: any(named: 'photos'),
              bio: any(named: 'bio'),
              interests: any(named: 'interests'),
              socialLinks: any(named: 'socialLinks'),
            )).thenAnswer((_) async {});
        when(() => mockUserService.getCurrentUser())
            .thenAnswer((_) async => sampleUser);
        when(() => mockEventService.getUserEvents('u-1'))
            .thenAnswer((_) async => [sampleEvent]);
        return ProfileBloc(
          userService: mockUserService,
          eventService: mockEventService,
        );
      },
      seed: () => ProfileLoaded(sampleUser, userEvents: [sampleEvent]),
      act: (bloc) => bloc.add(const ProfileUpdateRequested(
        displayName: 'New Name',
        bio: 'New bio',
      )),
      expect: () => [
        isA<ProfileUpdating>()
            .having((s) => s.user.id, 'user.id', 'u-1'),
        isA<ProfileLoaded>()
            .having((s) => s.user.id, 'user.id', 'u-1'),
      ],
    );

    blocTest<ProfileBloc, ProfileState>(
      'emits [ProfileUpdating, ProfileError] when updateProfile throws',
      build: () {
        when(() => mockUserService.updateProfile(
              displayName: any(named: 'displayName'),
              photoUrl: any(named: 'photoUrl'),
              photos: any(named: 'photos'),
              bio: any(named: 'bio'),
              interests: any(named: 'interests'),
              socialLinks: any(named: 'socialLinks'),
            )).thenThrow(Exception('update failed'));
        return ProfileBloc(
          userService: mockUserService,
          eventService: mockEventService,
        );
      },
      seed: () => ProfileLoaded(sampleUser, userEvents: []),
      act: (bloc) => bloc.add(const ProfileUpdateRequested(
        displayName: 'Fail',
      )),
      expect: () => [
        isA<ProfileUpdating>(),
        isA<ProfileError>()
            .having((s) => s.user, 'fallback user', isNotNull),
      ],
    );

    blocTest<ProfileBloc, ProfileState>(
      'ProfileUpdateRequested does nothing if state is not ProfileLoaded',
      build: () {
        return ProfileBloc(
          userService: mockUserService,
          eventService: mockEventService,
        );
      },
      act: (bloc) => bloc.add(const ProfileUpdateRequested(displayName: 'X')),
      expect: () => <ProfileState>[],
    );

    blocTest<ProfileBloc, ProfileState>(
      'ProfilePhotoUpdateRequested does nothing if state is not ProfileLoaded',
      build: () {
        return ProfileBloc(
          userService: mockUserService,
          eventService: mockEventService,
        );
      },
      act: (bloc) =>
          bloc.add(const ProfilePhotoUpdateRequested('/path/photo.jpg')),
      expect: () => <ProfileState>[],
    );
  });
}
