import 'package:flutter_test/flutter_test.dart';
import 'package:andexevents/presentation/events/bloc/event_event.dart';
import 'package:andexevents/presentation/events/bloc/event_state.dart';
import 'package:andexevents/data/models/event_model.dart';

void main() {
  final now = DateTime(2025, 6, 15, 18, 0, 0);
  final sampleEvent = EventModel.fromJson({
    'id': 'evt-1',
    'title': 'Test',
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

  group('EventEvent equality', () {
    test('EventsLoadRequested with same params are equal', () {
      expect(
        const EventsLoadRequested(page: 1, category: 'MUSIC'),
        equals(const EventsLoadRequested(page: 1, category: 'MUSIC')),
      );
    });

    test('EventsLoadRequested with different params are not equal', () {
      expect(
        const EventsLoadRequested(page: 1),
        isNot(equals(const EventsLoadRequested(page: 2))),
      );
    });

    test('EventDetailLoadRequested equality', () {
      expect(
        const EventDetailLoadRequested('evt-1'),
        equals(const EventDetailLoadRequested('evt-1')),
      );
      expect(
        const EventDetailLoadRequested('evt-1'),
        isNot(equals(const EventDetailLoadRequested('evt-2'))),
      );
    });

    test('EventDeleteRequested equality', () {
      expect(
        const EventDeleteRequested('evt-1'),
        equals(const EventDeleteRequested('evt-1')),
      );
    });

    test('EventParticipateRequested equality', () {
      expect(
        const EventParticipateRequested(eventId: 'evt-1', status: 'GOING'),
        equals(
            const EventParticipateRequested(eventId: 'evt-1', status: 'GOING')),
      );
      expect(
        const EventParticipateRequested(eventId: 'evt-1', status: 'GOING'),
        isNot(equals(const EventParticipateRequested(
            eventId: 'evt-1', status: 'INTERESTED'))),
      );
    });

    test('EventCancelParticipationRequested equality', () {
      expect(
        const EventCancelParticipationRequested('evt-1'),
        equals(const EventCancelParticipationRequested('evt-1')),
      );
    });

    test('EventPhotoUploadRequested equality', () {
      expect(
        const EventPhotoUploadRequested('/path/photo.jpg'),
        equals(const EventPhotoUploadRequested('/path/photo.jpg')),
      );
    });

    test('EventParticipantsLoadRequested equality', () {
      expect(
        const EventParticipantsLoadRequested('evt-1'),
        equals(const EventParticipantsLoadRequested('evt-1')),
      );
    });

    test('EventCreateRequested props contain all fields', () {
      final event = EventCreateRequested(
        title: 'T',
        description: 'D',
        category: 'C',
        location: 'L',
        latitude: 1.0,
        longitude: 2.0,
        dateTime: now,
        price: 0,
        isOnline: false,
      );
      expect(event.props.length, 14);
    });

    test('EventUpdateRequested props contain all fields', () {
      const event = EventUpdateRequested(eventId: 'evt-1', title: 'New');
      expect(event.props.length, 15);
    });
  });

  group('EventState equality', () {
    test('EventInitial instances are equal', () {
      expect(const EventInitial(), equals(const EventInitial()));
    });

    test('EventsLoading instances are equal', () {
      expect(const EventsLoading(), equals(const EventsLoading()));
    });

    test('EventError with same message are equal', () {
      expect(const EventError('err'), equals(const EventError('err')));
    });

    test('EventError with different messages are not equal', () {
      expect(const EventError('a'), isNot(equals(const EventError('b'))));
    });

    test('EventsLoaded equality by events, hasMore, currentPage', () {
      final state1 = EventsLoaded(events: [sampleEvent], hasMore: true);
      final state2 = EventsLoaded(events: [sampleEvent], hasMore: true);
      expect(state1, equals(state2));
    });

    test('EventsLoaded copyWith works', () {
      final original = EventsLoaded(
        events: [sampleEvent],
        hasMore: true,
        currentPage: 1,
      );
      final copy = original.copyWith(hasMore: false, currentPage: 2);
      expect(copy.hasMore, false);
      expect(copy.currentPage, 2);
      expect(copy.events.length, 1);
    });

    test('EventPhotoUploaded equality', () {
      expect(
        const EventPhotoUploaded('url'),
        equals(const EventPhotoUploaded('url')),
      );
    });

    test('EventDeleted instances are equal', () {
      expect(const EventDeleted(), equals(const EventDeleted()));
    });

    test('EventParticipationUpdated instances are equal', () {
      expect(
        const EventParticipationUpdated(),
        equals(const EventParticipationUpdated()),
      );
    });

    test('different state types are not equal', () {
      expect(const EventInitial(), isNot(equals(const EventsLoading())));
      expect(const EventCreating(), isNot(equals(const EventUpdating())));
      expect(const EventDeleting(), isNot(equals(const EventDeleted())));
    });
  });
}
