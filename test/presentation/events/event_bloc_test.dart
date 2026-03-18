import 'package:flutter_test/flutter_test.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:andexevents/presentation/events/bloc/event_bloc.dart';
import 'package:andexevents/presentation/events/bloc/event_event.dart';
import 'package:andexevents/presentation/events/bloc/event_state.dart';
import 'package:andexevents/data/services/event_service.dart';
import 'package:andexevents/data/models/event_model.dart';
import 'package:andexevents/data/models/participant_model.dart';

class MockEventService extends Mock implements EventService {}

// Fake classes for registerFallbackValue
class FakeFile extends Fake implements Object {}

void main() {
  late MockEventService mockEventService;

  final now = DateTime(2025, 6, 15, 18, 0);
  final sampleEvent = EventModel.fromJson({
    'id': 'evt-1',
    'title': 'Test Event',
    'description': 'Description',
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

  final sampleParticipant = ParticipantModel.fromJson({
    'id': 'p-1',
    'userId': 'u-2',
    'eventId': 'evt-1',
    'status': 'GOING',
    'joinedAt': now.toIso8601String(),
    'updatedAt': now.toIso8601String(),
    'user': {
      'id': 'u-2',
      'displayName': 'Participant',
    },
  });

  setUp(() {
    mockEventService = MockEventService();
  });

  group('EventBloc', () {
    test('initial state is EventInitial', () {
      final bloc = EventBloc(eventService: mockEventService);
      expect(bloc.state, const EventInitial());
      bloc.close();
    });

    blocTest<EventBloc, EventState>(
      'emits [EventsLoading, EventsLoaded] on EventsLoadRequested page 1',
      build: () {
        when(() => mockEventService.getEvents(
              category: any(named: 'category'),
              latitude: any(named: 'latitude'),
              longitude: any(named: 'longitude'),
              maxDistance: any(named: 'maxDistance'),
              page: any(named: 'page'),
              limit: any(named: 'limit'),
            )).thenAnswer((_) async => [sampleEvent]);
        return EventBloc(eventService: mockEventService);
      },
      act: (bloc) => bloc.add(const EventsLoadRequested(page: 1)),
      expect: () => [
        const EventsLoading(),
        isA<EventsLoaded>()
            .having((s) => s.events.length, 'events.length', 1)
            .having((s) => s.hasMore, 'hasMore', false)
            .having((s) => s.currentPage, 'currentPage', 1),
      ],
    );

    blocTest<EventBloc, EventState>(
      'emits [EventsLoading, EventError] when getEvents throws',
      build: () {
        when(() => mockEventService.getEvents(
              category: any(named: 'category'),
              latitude: any(named: 'latitude'),
              longitude: any(named: 'longitude'),
              maxDistance: any(named: 'maxDistance'),
              page: any(named: 'page'),
              limit: any(named: 'limit'),
            )).thenThrow(Exception('network error'));
        return EventBloc(eventService: mockEventService);
      },
      act: (bloc) => bloc.add(const EventsLoadRequested()),
      expect: () => [
        const EventsLoading(),
        isA<EventError>(),
      ],
    );

    blocTest<EventBloc, EventState>(
      'emits [EventDetailLoading, EventDetailLoaded] on detail load',
      build: () {
        when(() => mockEventService.getEventById('evt-1'))
            .thenAnswer((_) async => sampleEvent);
        return EventBloc(eventService: mockEventService);
      },
      act: (bloc) => bloc.add(const EventDetailLoadRequested('evt-1')),
      expect: () => [
        const EventDetailLoading(),
        isA<EventDetailLoaded>()
            .having((s) => s.event.id, 'event.id', 'evt-1'),
      ],
    );

    blocTest<EventBloc, EventState>(
      'emits [EventDetailLoading, EventError] when getEventById throws',
      build: () {
        when(() => mockEventService.getEventById('evt-1'))
            .thenThrow(Exception('not found'));
        return EventBloc(eventService: mockEventService);
      },
      act: (bloc) => bloc.add(const EventDetailLoadRequested('evt-1')),
      expect: () => [
        const EventDetailLoading(),
        isA<EventError>(),
      ],
    );

    blocTest<EventBloc, EventState>(
      'emits [EventCreating, EventCreated] on create',
      build: () {
        when(() => mockEventService.createEvent(
              title: any(named: 'title'),
              description: any(named: 'description'),
              category: any(named: 'category'),
              location: any(named: 'location'),
              latitude: any(named: 'latitude'),
              longitude: any(named: 'longitude'),
              dateTime: any(named: 'dateTime'),
              endDateTime: any(named: 'endDateTime'),
              price: any(named: 'price'),
              imageUrl: any(named: 'imageUrl'),
              isOnline: any(named: 'isOnline'),
              maxParticipants: any(named: 'maxParticipants'),
              minAge: any(named: 'minAge'),
              maxAge: any(named: 'maxAge'),
            )).thenAnswer((_) async => sampleEvent);
        return EventBloc(eventService: mockEventService);
      },
      act: (bloc) => bloc.add(EventCreateRequested(
        title: 'Test',
        description: 'Desc',
        category: 'MUSIC',
        location: 'Moscow',
        latitude: 55.75,
        longitude: 37.61,
        dateTime: now,
        price: 0,
        isOnline: false,
      )),
      expect: () => [
        const EventCreating(),
        isA<EventCreated>(),
      ],
    );

    blocTest<EventBloc, EventState>(
      'emits [EventParticipantsLoading, EventParticipantsLoaded]',
      build: () {
        when(() => mockEventService.getEventParticipants('evt-1'))
            .thenAnswer((_) async => [sampleParticipant]);
        return EventBloc(eventService: mockEventService);
      },
      act: (bloc) =>
          bloc.add(const EventParticipantsLoadRequested('evt-1')),
      expect: () => [
        const EventParticipantsLoading(),
        isA<EventParticipantsLoaded>()
            .having((s) => s.participants.length, 'count', 1),
      ],
    );

    blocTest<EventBloc, EventState>(
      'emits [EventDeleting, EventDeleted] on delete',
      build: () {
        when(() => mockEventService.deleteEvent('evt-1'))
            .thenAnswer((_) async {});
        return EventBloc(eventService: mockEventService);
      },
      act: (bloc) => bloc.add(const EventDeleteRequested('evt-1')),
      expect: () => [
        const EventDeleting(),
        const EventDeleted(),
      ],
    );

    blocTest<EventBloc, EventState>(
      'emits [EventDeleting, EventError] when delete throws',
      build: () {
        when(() => mockEventService.deleteEvent('evt-1'))
            .thenThrow(Exception('forbidden'));
        return EventBloc(eventService: mockEventService);
      },
      act: (bloc) => bloc.add(const EventDeleteRequested('evt-1')),
      expect: () => [
        const EventDeleting(),
        isA<EventError>(),
      ],
    );

    blocTest<EventBloc, EventState>(
      'emits [EventUpdating, EventUpdated] on update',
      build: () {
        when(() => mockEventService.updateEvent(
              eventId: any(named: 'eventId'),
              title: any(named: 'title'),
              description: any(named: 'description'),
              category: any(named: 'category'),
              location: any(named: 'location'),
              latitude: any(named: 'latitude'),
              longitude: any(named: 'longitude'),
              dateTime: any(named: 'dateTime'),
              endDateTime: any(named: 'endDateTime'),
              price: any(named: 'price'),
              imageUrl: any(named: 'imageUrl'),
              isOnline: any(named: 'isOnline'),
              maxParticipants: any(named: 'maxParticipants'),
              minAge: any(named: 'minAge'),
              maxAge: any(named: 'maxAge'),
            )).thenAnswer((_) async => sampleEvent);
        return EventBloc(eventService: mockEventService);
      },
      act: (bloc) => bloc.add(const EventUpdateRequested(
        eventId: 'evt-1',
        title: 'Updated',
      )),
      expect: () => [
        const EventUpdating(),
        isA<EventUpdated>(),
      ],
    );

    blocTest<EventBloc, EventState>(
      'pagination appends events on page > 1',
      build: () {
        when(() => mockEventService.getEvents(
              category: any(named: 'category'),
              latitude: any(named: 'latitude'),
              longitude: any(named: 'longitude'),
              maxDistance: any(named: 'maxDistance'),
              page: any(named: 'page'),
              limit: any(named: 'limit'),
            )).thenAnswer((_) async => [sampleEvent]);
        return EventBloc(eventService: mockEventService);
      },
      seed: () => EventsLoaded(
        events: [sampleEvent],
        hasMore: true,
        currentPage: 1,
      ),
      act: (bloc) => bloc.add(const EventsLoadRequested(page: 2)),
      expect: () => [
        isA<EventsLoaded>()
            .having((s) => s.events.length, 'events.length', 2)
            .having((s) => s.currentPage, 'currentPage', 2),
      ],
    );
  });
}
