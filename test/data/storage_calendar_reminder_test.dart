import 'package:chance_affair/data/calendar_service.dart';
import 'package:chance_affair/data/local_storage.dart';
import 'package:chance_affair/data/reminder_service.dart';
import 'package:chance_affair/domain/app_settings.dart';
import 'package:chance_affair/domain/schedule.dart';
import 'package:chance_affair/domain/user_profile.dart';
import 'package:device_calendar/device_calendar.dart' as dc;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

void main() {
  group('LocalStorage', () {
    late LocalStorage storage;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      storage = LocalStorage(await SharedPreferences.getInstance());
    });

    test('по умолчанию — пустой профиль и стандартные настройки', () {
      expect(storage.loadProfile(), UserProfile.empty);
      expect(storage.loadSettings(), AppSettings.defaults);
    });

    test('сохраняет и читает профиль и настройки', () async {
      const p = UserProfile(name: 'Ира', hobbies: ['Йога']);
      const s = AppSettings(defaultDay: ScheduleDay.tomorrow);
      await storage.saveProfile(p);
      await storage.saveSettings(s);
      expect(storage.loadProfile(), p);
      expect(storage.loadSettings(), s);
    });

    test('повреждённые данные не ломают приложение', () async {
      SharedPreferences.setMockInitialValues({
        'user_profile_v1': '{битый',
        'app_settings_v1': '[]',
      });
      final broken = LocalStorage(await SharedPreferences.getInstance());
      expect(broken.loadProfile(), UserProfile.empty);
      expect(broken.loadSettings(), AppSettings.defaults);
    });
  });

  group('pickWritableCalendar', () {
    dc.Calendar cal(
      String id, {
      bool readOnly = false,
      bool isDefault = false,
    }) => dc.Calendar(id: id, isReadOnly: readOnly, isDefault: isDefault);

    test('предпочитает календарь по умолчанию', () {
      final c = pickWritableCalendar([cal('a'), cal('b', isDefault: true)]);
      expect(c?.id, 'b');
    });

    test('пропускает календари только для чтения', () {
      final c = pickWritableCalendar([
        cal('holidays', readOnly: true, isDefault: true),
        cal('mine'),
      ]);
      expect(c?.id, 'mine');
    });

    test('null, если писать некуда', () {
      expect(pickWritableCalendar([cal('x', readOnly: true)]), isNull);
      expect(pickWritableCalendar([]), isNull);
    });
  });

  group('nextInstanceOf', () {
    setUpAll(tzdata.initializeTimeZones);

    test('сегодня, если время ещё не наступило', () {
      final loc = tz.getLocation('Europe/Moscow');
      final now = tz.TZDateTime(loc, 2026, 10, 8, 9);
      expect(
        nextInstanceOf(10, 30, now),
        tz.TZDateTime(loc, 2026, 10, 8, 10, 30),
      );
    });

    test('завтра, если время уже прошло', () {
      final loc = tz.getLocation('Europe/Moscow');
      final now = tz.TZDateTime(loc, 2026, 10, 31, 12);
      expect(nextInstanceOf(10, 0, now), tz.TZDateTime(loc, 2026, 11, 1, 10));
    });
  });
}
