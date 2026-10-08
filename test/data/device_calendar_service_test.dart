import 'dart:collection';

import 'package:chance_affair/data/calendar_service.dart';
import 'package:device_calendar/device_calendar.dart' as dc;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:timezone/data/latest.dart' as tzdata;

class _MockPlugin extends Mock implements dc.DeviceCalendarPlugin {}

dc.Result<T> _ok<T>(T data) => dc.Result<T>()..data = data;

void main() {
  late _MockPlugin plugin;
  late DeviceCalendarService service;

  setUpAll(() {
    tzdata.initializeTimeZones();
    registerFallbackValue(dc.Event('x'));
  });

  setUp(() {
    plugin = _MockPlugin();
    service = DeviceCalendarService(plugin);
    when(() => plugin.hasPermissions()).thenAnswer((_) async => _ok(true));
    when(() => plugin.retrieveCalendars()).thenAnswer(
      (_) async => _ok(
        UnmodifiableListView([
          dc.Calendar(id: 'cal-1', isDefault: true, isReadOnly: false),
        ]),
      ),
    );
    when(() => plugin.createOrUpdateEvent(any()))
        .thenAnswer((_) async => _ok('evt-1'));
  });

  Future<String> add() => service.addEvent(
    title: '🦆 Утки',
    description: 'Покормить уток',
    start: DateTime(2026, 10, 9, 15),
    end: DateTime(2026, 10, 9, 16),
  );

  test('создаёт событие с напоминанием в календаре по умолчанию', () async {
    expect(await add(), 'evt-1');

    final event =
        verify(() => plugin.createOrUpdateEvent(captureAny())).captured.single
            as dc.Event;
    expect(event.calendarId, 'cal-1');
    expect(event.title, '🦆 Утки');
    expect(event.description, 'Покормить уток');
    // Тот же момент времени, независимо от часового пояса.
    expect(event.start!.isAtSameMomentAs(DateTime(2026, 10, 9, 15)), isTrue);
    expect(event.end!.isAtSameMomentAs(DateTime(2026, 10, 9, 16)), isTrue);
    expect(event.reminders!.single.minutes, 30);
    verifyNever(() => plugin.requestPermissions());
  });

  test('запрашивает доступ, если его ещё нет', () async {
    when(() => plugin.hasPermissions()).thenAnswer((_) async => _ok(false));
    when(() => plugin.requestPermissions()).thenAnswer((_) async => _ok(true));
    expect(await add(), 'evt-1');
    verify(() => plugin.requestPermissions()).called(1);
  });

  test('отказ в доступе → понятная ошибка', () async {
    when(() => plugin.hasPermissions()).thenAnswer((_) async => _ok(false));
    when(() => plugin.requestPermissions()).thenAnswer((_) async => _ok(false));
    expect(
      add(),
      throwsA(
        isA<CalendarException>().having(
          (e) => e.message,
          'message',
          contains('Нет доступа'),
        ),
      ),
    );
  });

  test('нет доступных календарей → создаёт свой локальный', () async {
    when(() => plugin.retrieveCalendars()).thenAnswer(
      (_) async =>
          _ok(UnmodifiableListView([dc.Calendar(id: 'ro', isReadOnly: true)])),
    );
    when(
      () => plugin.createCalendar(
        any(),
        calendarColor: any(named: 'calendarColor'),
        localAccountName: any(named: 'localAccountName'),
      ),
    ).thenAnswer((_) async => _ok('own'));

    expect(await add(), 'evt-1');
    final event =
        verify(() => plugin.createOrUpdateEvent(captureAny())).captured.single
            as dc.Event;
    expect(event.calendarId, 'own');
  });

  test('не удалось создать календарь → понятная ошибка', () async {
    when(() => plugin.retrieveCalendars())
        .thenAnswer((_) async => _ok(UnmodifiableListView(<dc.Calendar>[])));
    when(
      () => plugin.createCalendar(
        any(),
        calendarColor: any(named: 'calendarColor'),
        localAccountName: any(named: 'localAccountName'),
      ),
    ).thenAnswer((_) async => dc.Result<String>());
    expect(add(), throwsA(isA<CalendarException>()));
  });

  test('сбой записи → понятная ошибка', () async {
    when(() => plugin.createOrUpdateEvent(any()))
        .thenAnswer((_) async => dc.Result<String>());
    expect(
      add(),
      throwsA(
        isA<CalendarException>().having(
          (e) => e.message,
          'message',
          contains('Не удалось'),
        ),
      ),
    );
  });
}
