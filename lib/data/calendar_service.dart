import 'package:device_calendar/device_calendar.dart' as dc;
import 'package:flutter/painting.dart';
import 'package:timezone/timezone.dart' as tz;

/// Запись событий в системный календарь телефона.
abstract interface class CalendarService {
  /// Создаёт событие и возвращает его идентификатор.
  Future<String> addEvent({
    required String title,
    required String description,
    required DateTime start,
    required DateTime end,
  });
}

class CalendarException implements Exception {
  const CalendarException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Выбирает календарь для записи: по умолчанию, иначе первый доступный.
dc.Calendar? pickWritableCalendar(Iterable<dc.Calendar> calendars) {
  final writable = calendars.where((c) => c.isReadOnly != true).toList();
  if (writable.isEmpty) return null;
  return writable.firstWhere(
    (c) => c.isDefault == true,
    orElse: () => writable.first,
  );
}

class DeviceCalendarService implements CalendarService {
  DeviceCalendarService([dc.DeviceCalendarPlugin? plugin])
    : _plugin = plugin ?? dc.DeviceCalendarPlugin();

  final dc.DeviceCalendarPlugin _plugin;

  @override
  Future<String> addEvent({
    required String title,
    required String description,
    required DateTime start,
    required DateTime end,
  }) async {
    var granted = (await _plugin.hasPermissions()).data ?? false;
    if (!granted) {
      granted = (await _plugin.requestPermissions()).data ?? false;
    }
    if (!granted) {
      throw const CalendarException(
        'Нет доступа к календарю. Разрешите его в настройках телефона.',
      );
    }

    final calendars =
        (await _plugin.retrieveCalendars()).data ?? const <dc.Calendar>[];
    final calendarId =
        pickWritableCalendar(calendars)?.id ?? await _createOwnCalendar();

    final event = dc.Event(
      calendarId,
      title: title,
      description: description,
      start: tz.TZDateTime.from(start, tz.local),
      end: tz.TZDateTime.from(end, tz.local),
      reminders: [dc.Reminder(minutes: 30)],
    );
    final result = await _plugin.createOrUpdateEvent(event);
    final id = result?.data;
    if (result == null || !result.isSuccess || id == null) {
      throw const CalendarException('Не удалось записать событие в календарь.');
    }
    return id;
  }

  /// Телефон без аккаунтов: создаём локальный календарь приложения.
  Future<String> _createOwnCalendar() async {
    final result = await _plugin.createCalendar(
      ownCalendarName,
      calendarColor: const Color(0xFFE8693A),
      localAccountName: ownCalendarName,
    );
    final id = result.data;
    if (!result.isSuccess || id == null) {
      throw const CalendarException(
        'На телефоне не найден календарь, в который можно записать событие.',
      );
    }
    return id;
  }

  static const ownCalendarName = 'Чем заняться?';
}
