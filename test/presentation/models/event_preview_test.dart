import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:andexevents/presentation/models/event_preview.dart';

void main() {
  final testDate = DateTime(2025, 7, 1);

  group('EventPreview', () {
    test('isFree returns true when price is null', () {
      final preview = EventPreview(
        title: 'Free Event',
        category: 'MUSIC',
        time: '18:00',
        distance: '1.5 km',
        badgeColor: Colors.blue,
        attendees: 10,
        date: testDate,
        location: 'Moscow',
        price: null,
      );
      expect(preview.isFree, true);
    });

    test('isFree returns true when price is 0', () {
      final preview = EventPreview(
        title: 'Free Event',
        category: 'MUSIC',
        time: '18:00',
        distance: '1.5 km',
        badgeColor: Colors.blue,
        attendees: 10,
        date: testDate,
        location: 'Moscow',
        price: 0,
      );
      expect(preview.isFree, true);
    });

    test('isFree returns false when price is positive', () {
      final preview = EventPreview(
        title: 'Paid Event',
        category: 'MUSIC',
        time: '18:00',
        distance: '1.5 km',
        badgeColor: Colors.blue,
        attendees: 10,
        date: testDate,
        location: 'Moscow',
        price: 500,
      );
      expect(preview.isFree, false);
    });

    test('default attendeeNames is empty', () {
      final preview = EventPreview(
        title: 'Event',
        category: 'SPORTS',
        time: '20:00',
        distance: '3 km',
        badgeColor: Colors.green,
        attendees: 5,
        date: testDate,
        location: 'Park',
      );
      expect(preview.attendeeNames, isEmpty);
    });

    test('all fields are correctly stored', () {
      final date = DateTime(2025, 7, 1);
      final preview = EventPreview(
        title: 'Concert',
        category: 'MUSIC',
        time: '21:00',
        distance: '500 m',
        badgeColor: Colors.red,
        attendees: 200,
        date: date,
        location: 'Arena',
        price: 1500,
        attendeeNames: ['Alice', 'Bob'],
      );

      expect(preview.title, 'Concert');
      expect(preview.category, 'MUSIC');
      expect(preview.time, '21:00');
      expect(preview.distance, '500 m');
      expect(preview.badgeColor, Colors.red);
      expect(preview.attendees, 200);
      expect(preview.date, date);
      expect(preview.location, 'Arena');
      expect(preview.price, 1500);
      expect(preview.attendeeNames, ['Alice', 'Bob']);
    });
  });
}
