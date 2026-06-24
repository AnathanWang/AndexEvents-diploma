import 'package:add_2_calendar/add_2_calendar.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/services/logger_service.dart';
import '../models/event_model.dart';

class CalendarService {
  Future<bool> _ensureCalendarPermission() async {
    if (kIsWeb) return false;
    if (defaultTargetPlatform != TargetPlatform.iOS &&
        defaultTargetPlatform != TargetPlatform.android) {
      return false;
    }

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      var status = await Permission.calendarFullAccess.status;
      if (!status.isGranted && !status.isLimited) {
        status = await Permission.calendarFullAccess.request();
      }
      if (status.isGranted || status.isLimited) return true;

      status = await Permission.calendarWriteOnly.status;
      if (!status.isGranted) {
        status = await Permission.calendarWriteOnly.request();
      }
      return status.isGranted;
    }

    var status = await Permission.calendarFullAccess.status;
    if (!status.isGranted) {
      status = await Permission.calendarFullAccess.request();
    }
    if (status.isGranted) return true;

    status = await Permission.calendarWriteOnly.status;
    if (!status.isGranted) {
      status = await Permission.calendarWriteOnly.request();
    }
    return status.isGranted;
  }

  Future<void> addEventToCalendar(EventModel event) async {
    if (kIsWeb) {
      throw Exception('Календарь недоступен в web-версии');
    }
    if (defaultTargetPlatform != TargetPlatform.iOS &&
        defaultTargetPlatform != TargetPlatform.android) {
      throw Exception('Календарь доступен только на iOS и Android');
    }

    final hasPermission = await _ensureCalendarPermission();
    if (!hasPermission) {
      throw Exception('Нет доступа к календарю. Разрешите в настройках устройства');
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
      androidParams: const AndroidParams(
        emailInvites: <String>[],
      ),
    );

    try {
      final ok = await Add2Calendar.addEvent2Cal(calEvent);
      if (!ok) {
        throw Exception('Не удалось открыть календарь на этом устройстве');
      }
    } catch (e, st) {
      LoggerService.error('[CalendarService] Failed to add calendar event', e, st);
      rethrow;
    }
  }
}
