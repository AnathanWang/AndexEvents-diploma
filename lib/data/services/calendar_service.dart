import 'package:add_2_calendar/add_2_calendar.dart';
import 'package:flutter/foundation.dart';

import '../../core/services/logger_service.dart';
import '../models/event_model.dart';

class CalendarService {
  Future<void> addEventToCalendar(EventModel event) async {
    if (kIsWeb) {
      throw Exception('Календарь недоступен в web-версии');
    }
    if (defaultTargetPlatform != TargetPlatform.iOS &&
        defaultTargetPlatform != TargetPlatform.android) {
      throw Exception('Календарь доступен только на iOS и Android');
    }

    final start = event.dateTime.toLocal();
    final end = event.actualEndDateTime.toLocal();

    final location = event.isOnline ? 'Online' : event.location;

    final calEvent = Event(
      title: event.title,
      description: event.description,
      location: location,
      startDate: start,
      endDate: end.isAfter(start) ? end : start.add(const Duration(hours: 1)),
      iosParams: const IOSParams(
        reminder: Duration(hours: 1),
      ),
    );

    try {
      final ok = await Add2Calendar.addEvent2Cal(calEvent);
      if (!ok) {
        throw Exception('Операция отменена или недоступна');
      }
    } catch (e, st) {
      LoggerService.error('[CalendarService] Failed to add calendar event', e, st);
      rethrow;
    }
  }
}

