import 'package:chance_affair/data/activity_generator.dart';
import 'package:chance_affair/data/calendar_service.dart';
import 'package:chance_affair/data/groq_activity_generator.dart';
import 'package:chance_affair/domain/activity.dart';
import 'package:chance_affair/domain/app_settings.dart';
import 'package:chance_affair/domain/schedule.dart';
import 'package:chance_affair/domain/user_profile.dart';
import 'package:chance_affair/state/providers.dart';
import 'package:chance_affair/state/suggestion_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/fakes.dart';

const _museum = Activity(
  title: 'Музей',
  description: 'Сходить в музей',
  category: 'Культура',
  preferredStartHour: 12,
  durationMinutes: 120,
);

void main() {
  group('SuggestionController', () {
    test('по умолчанию берёт день из настроек', () async {
      final c = await makeContainer(
        prefs: {'app_settings_v1': '{"defaultDay":"tomorrow"}'},
      );
      expect(c.read(suggestionControllerProvider).day, ScheduleDay.tomorrow);
    });

    test('без ключа ИИ берёт идею из каталога', () async {
      final offline = FakeGenerator([sampleActivity]);
      final c = await makeContainer(offline: offline);
      await c.read(suggestionControllerProvider.notifier).suggest();

      final s = c.read(suggestionControllerProvider);
      expect(s.status, SuggestionStatus.ready);
      expect(s.activity, sampleActivity);
      expect(s.fromAi, isFalse);
      expect(s.message, isNull);
      expect(offline.requests.single.now, fixedNow);
    });

    test('с ИИ использует ИИ и передаёт профиль', () async {
      final ai = FakeGenerator([_museum]);
      final c = await makeContainer(
        ai: ai,
        prefs: {'user_profile_v1': '{"city":"Пермь"}'},
      );
      await c.read(suggestionControllerProvider.notifier).suggest();

      final s = c.read(suggestionControllerProvider);
      expect(s.activity, _museum);
      expect(s.fromAi, isTrue);
      expect(ai.requests.single.profile.city, 'Пермь');
    });

    test('если ИИ упал — запасной вариант из каталога с пояснением', () async {
      final c = await makeContainer(
        ai: FakeGenerator([
          const ActivityGenerationException('Лимит исчерпан.'),
        ]),
      );
      await c.read(suggestionControllerProvider.notifier).suggest();

      final s = c.read(suggestionControllerProvider);
      expect(s.status, SuggestionStatus.ready);
      expect(s.fromAi, isFalse);
      expect(s.message, contains('Лимит исчерпан.'));
      expect(s.message, contains('каталога'));
    });

    test('если всё упало — состояние ошибки', () async {
      final c = await makeContainer(
        offline: FakeGenerator([Exception('boom')]),
      );
      await c.read(suggestionControllerProvider.notifier).suggest();
      expect(
        c.read(suggestionControllerProvider).status,
        SuggestionStatus.error,
      );
    });

    test('«Другое» запоминает отклонённую идею и не повторяет её', () async {
      final ai = FakeGenerator([sampleActivity, _museum]);
      final c = await makeContainer(ai: ai);
      final ctrl = c.read(suggestionControllerProvider.notifier);
      await ctrl.suggest();
      await ctrl.suggest();

      expect(ai.requests[1].excludeTitles, [sampleActivity.title]);
      expect(c.read(suggestionControllerProvider).activity, _museum);
    });

    test('хранит не больше 15 отклонённых', () async {
      final c = await makeContainer();
      final ctrl = c.read(suggestionControllerProvider.notifier);
      for (var i = 0; i < 20; i++) {
        await ctrl.suggest();
      }
      expect(
        c.read(suggestionControllerProvider).rejected.length,
        SuggestionController.maxRejected,
      );
    });

    test(
      '«Согласиться» записывает событие в календарь на выбранный день',
      () async {
        final calendar = FakeCalendar();
        final c = await makeContainer(calendar: calendar);
        final ctrl = c.read(suggestionControllerProvider.notifier);
        ctrl.selectDay(ScheduleDay.tomorrow);
        await ctrl.suggest();
        await ctrl.accept();

        final s = c.read(suggestionControllerProvider);
        expect(s.status, SuggestionStatus.saved);
        final event = calendar.events.single;
        expect(event.title, '🦆 Покормить уток');
        expect(event.start, DateTime(2026, 10, 9, 15));
        expect(event.end, DateTime(2026, 10, 9, 16, 30));
        expect(s.savedSlot!.start, event.start);
      },
    );

    test('ошибка календаря показывается, идея остаётся', () async {
      final c = await makeContainer(
        calendar: FakeCalendar(error: const CalendarException('Нет доступа')),
      );
      final ctrl = c.read(suggestionControllerProvider.notifier);
      await ctrl.suggest();
      await ctrl.accept();

      final s = c.read(suggestionControllerProvider);
      expect(s.status, SuggestionStatus.ready);
      expect(s.message, 'Нет доступа');
      expect(s.activity, sampleActivity);
    });

    test('accept без идеи ничего не делает', () async {
      final calendar = FakeCalendar();
      final c = await makeContainer(calendar: calendar);
      await c.read(suggestionControllerProvider.notifier).accept();
      expect(calendar.events, isEmpty);
    });

    test('reset возвращает в начало, сохраняя день', () async {
      final c = await makeContainer();
      final ctrl = c.read(suggestionControllerProvider.notifier);
      ctrl.selectDay(ScheduleDay.tomorrow);
      await ctrl.suggest();
      ctrl.reset();
      final s = c.read(suggestionControllerProvider);
      expect(s.status, SuggestionStatus.idle);
      expect(s.day, ScheduleDay.tomorrow);
      expect(s.activity, isNull);
    });
  });

  group('ProfileNotifier', () {
    test('сохраняет профиль на устройство', () async {
      final c = await makeContainer();
      await c
          .read(profileProvider.notifier)
          .save(const UserProfile(name: 'Оля', city: 'Сочи'));
      expect(c.read(profileProvider).city, 'Сочи');
      expect(c.read(localStorageProvider).loadProfile().name, 'Оля');
    });
  });

  group('SettingsNotifier', () {
    test('включение напоминаний планирует уведомление', () async {
      final reminders = FakeReminders();
      final c = await makeContainer(reminders: reminders);
      final ok = await c
          .read(settingsProvider.notifier)
          .setRemindersEnabled(true);

      expect(ok, isTrue);
      expect(c.read(settingsProvider).remindersEnabled, isTrue);
      expect(reminders.scheduled, (hour: 10, minute: 0));
      expect(
        c.read(localStorageProvider).loadSettings().remindersEnabled,
        isTrue,
      );
    });

    test('без разрешения напоминания не включаются', () async {
      final reminders = FakeReminders(permission: false);
      final c = await makeContainer(reminders: reminders);
      final ok = await c
          .read(settingsProvider.notifier)
          .setRemindersEnabled(true);

      expect(ok, isFalse);
      expect(c.read(settingsProvider).remindersEnabled, isFalse);
      expect(reminders.scheduled, isNull);
    });

    test('смена времени перепланирует включённое напоминание', () async {
      final reminders = FakeReminders();
      final c = await makeContainer(reminders: reminders);
      final n = c.read(settingsProvider.notifier);
      await n.setRemindersEnabled(true);
      await n.setReminderTime(19, 30);
      expect(reminders.scheduled, (hour: 19, minute: 30));
      expect(c.read(settingsProvider).reminderHour, 19);
    });

    test(
      'смена времени при выключенных напоминаниях ничего не планирует',
      () async {
        final reminders = FakeReminders();
        final c = await makeContainer(reminders: reminders);
        await c.read(settingsProvider.notifier).setReminderTime(8, 15);
        expect(reminders.scheduled, isNull);
      },
    );

    test('выключение отменяет напоминание', () async {
      final reminders = FakeReminders();
      final c = await makeContainer(reminders: reminders);
      final n = c.read(settingsProvider.notifier);
      await n.setRemindersEnabled(true);
      await n.setRemindersEnabled(false);
      expect(reminders.cancelCalls, 1);
      expect(c.read(settingsProvider).remindersEnabled, isFalse);
    });

    Future<ProviderContainer> keys({String builtIn = ''}) async {
      SharedPreferences.setMockInitialValues({});
      return ProviderContainer.test(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(
            await SharedPreferences.getInstance(),
          ),
          builtInApiKeyProvider.overrideWithValue(builtIn),
        ],
      );
    }

    String? activeKey(ProviderContainer c) =>
        (c.read(aiGeneratorProvider) as GroqActivityGenerator?)?.apiKey;

    test('без ключей ИИ выключен — работает каталог', () async {
      final c = await keys();
      expect(c.read(aiGeneratorProvider), isNull);
    });

    test('по умолчанию используется встроенный ключ', () async {
      final c = await keys(builtIn: 'gsk_built_in');
      expect(activeKey(c), 'gsk_built_in');
    });

    test(
      'свой ключ заменяет встроенный, сброс возвращает встроенный',
      () async {
        final c = await keys(builtIn: 'gsk_built_in');
        final n = c.read(settingsProvider.notifier);

        await n.update(const AppSettings(customApiKey: 'gsk_new'));
        expect(activeKey(c), 'gsk_new');
        expect(
          c.read(localStorageProvider).loadSettings().customApiKey,
          'gsk_new',
        );

        await n.update(const AppSettings());
        expect(activeKey(c), 'gsk_built_in');
      },
    );
  });
}
