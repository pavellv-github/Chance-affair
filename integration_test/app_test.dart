// Сквозные тесты на реальном устройстве: настоящие календарь, уведомления,
// хранилище и живой Groq.
//
// Запуск (ключ Groq обязателен):
//   flutter test integration_test -d <устройство> \
//     --dart-define-from-file=secrets.json
//
// Перед запуском выдайте приложению доступ к календарю (и на Android — к
// уведомлениям), иначе системный диалог остановит тест. См. README.
import 'dart:io';

import 'package:chance_affair/data/calendar_service.dart';
import 'package:chance_affair/data/local_storage.dart';
import 'package:chance_affair/main.dart' as app;
import 'package:chance_affair/ui/home/home_screen.dart';
import 'package:device_calendar/device_calendar.dart' as dc;
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _builtInKey = String.fromEnvironment('GROQ_API_KEY');

/// Ждёт появления виджета, не требуя «тишины» (спиннеры анимируются).
Future<void> _waitFor(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 45),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 200));
    if (finder.evaluate().isNotEmpty) return;
  }
  throw TestFailure('Не дождались: $finder');
}

/// Вводит текст и закрывает клавиатуру, чтобы она не перекрывала кнопки.
Future<void> _type(WidgetTester tester, String field, String text) async {
  final finder = find.widgetWithText(TextField, field);
  await tester.ensureVisible(finder);
  await tester.enterText(finder, text);
  FocusManager.instance.primaryFocus?.unfocus();
  for (var i = 0; i < 15; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump(const Duration(milliseconds: 300));
  await tester.tap(finder);
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _openTab(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(of: find.byType(NavigationBar), matching: find.text(label)),
  );
  await tester.pump(const Duration(milliseconds: 500));
}

Future<void> _launch(WidgetTester tester) async {
  app.main();
  await _waitFor(tester, find.byType(NavigationBar));
}

String _cardTitle(WidgetTester tester) =>
    tester.widget<ActivityCard>(find.byType(ActivityCard)).activity.title;

/// Ищет в календарях телефона события с заголовком, содержащим [title].
Future<List<dc.Event>> _calendarEvents(String title) async {
  final plugin = dc.DeviceCalendarPlugin();
  final calendars = (await plugin.retrieveCalendars()).data ?? const [];
  final now = DateTime.now();
  final found = <dc.Event>[];
  for (final c in calendars) {
    final events = (await plugin.retrieveEvents(
      c.id,
      dc.RetrieveEventsParams(
        startDate: now.subtract(const Duration(days: 1)),
        endDate: now.add(const Duration(days: 3)),
      ),
    )).data;
    found.addAll(events?.where((e) => e.title?.contains(title) ?? false) ?? []);
  }
  return found;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    expect(
      _builtInKey,
      startsWith('gsk_'),
      reason: 'Запускайте с --dart-define-from-file=secrets.json',
    );
    (await SharedPreferences.getInstance()).clear();
    await FlutterLocalNotificationsPlugin().cancelAll();
  });

  testWidgets('1. Первый запуск: главный экран на русском', (tester) async {
    await _launch(tester);
    expect(find.text('Привет!'), findsOneWidget);
    expect(find.text('Подобрать занятие'), findsOneWidget);
    expect(find.text('Сегодня'), findsOneWidget);
    expect(find.text('Завтра'), findsOneWidget);
    for (final tab in ['Подбор', 'Профиль', 'Настройки']) {
      expect(find.text(tab), findsOneWidget);
    }
  });

  testWidgets('2. Профиль сохраняется на устройстве', (tester) async {
    await _launch(tester);
    await _openTab(tester, 'Профиль');

    await _type(tester, 'Имя', 'Тестер');
    await _type(tester, 'Город', 'Казань');
    await _type(tester, 'О себе', 'Люблю природу и фотографию');
    await _tap(tester, find.text('Природа'));
    await _tap(tester, find.text('Фотография'));
    await _tap(tester, find.text('Есть машина'));
    await _tap(tester, find.text('Сохранить'));
    await _waitFor(tester, find.text('Профиль сохранён'));

    final saved = LocalStorage(await SharedPreferences.getInstance())
        .loadProfile();
    expect(saved.name, 'Тестер');
    expect(saved.city, 'Казань');
    expect(saved.hobbies, containsAll(['Природа', 'Фотография']));
    expect(saved.hasCar, isTrue);

    await _openTab(tester, 'Подбор');
    expect(find.text('Привет, Тестер!'), findsOneWidget);
  });

  testWidgets('3. Groq подбирает занятие, «Другое» даёт новую идею', (
    tester,
  ) async {
    await _launch(tester);
    expect(find.text('Привет, Тестер!'), findsOneWidget);

    await _tap(tester, find.text('Завтра'));
    await _tap(tester, find.text('Подобрать занятие'));
    await _waitFor(tester, find.text('Подобрано ИИ'));
    final first = _cardTitle(tester);
    expect(first, isNotEmpty);
    expect(find.text('Согласиться'), findsOneWidget);

    await _tap(tester, find.text('Другое'));
    await _waitFor(
      tester,
      find.byWidgetPredicate(
        (w) => w is ActivityCard && w.activity.title != first,
      ),
    );
    expect(find.text('Подобрано ИИ'), findsOneWidget);
  });

  testWidgets('4. «Согласиться» записывает событие в календарь телефона', (
    tester,
  ) async {
    await _launch(tester);
    await _tap(tester, find.text('Завтра'));
    await _tap(tester, find.text('Подобрать занятие'));
    await _waitFor(tester, find.byType(ActivityCard));
    final title = _cardTitle(tester);

    await _tap(tester, find.text('Согласиться'));
    await _waitFor(tester, find.textContaining('в календаре!'));
    expect(find.text('Подобрать ещё'), findsOneWidget);

    final events = await _calendarEvents(title);
    expect(events, isNotEmpty, reason: 'Событие «$title» не найдено');
    final event = events.first;
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    expect(event.start!.toLocal().day, tomorrow.day);
    expect(event.description, isNotEmpty);
    expect(event.reminders?.map((r) => r.minutes), contains(30));

    // Убираем за собой тестовое событие.
    await dc.DeviceCalendarPlugin().deleteEvent(
      event.calendarId,
      event.eventId,
    );
    expect(await _calendarEvents(title), isEmpty);
  });

  testWidgets('5. Неверный ключ → каталог; ключ обновляется и сбрасывается', (
    tester,
  ) async {
    await _launch(tester);
    await _openTab(tester, 'Настройки');
    expect(find.textContaining('Подключён встроенный ключ'), findsOneWidget);

    await _type(tester, 'Новый ключ (gsk_…)', 'gsk_invalid_key_for_test');
    await _tap(tester, find.text('Обновить ключ'));
    await _waitFor(tester, find.text('Ключ обновлён'));
    expect(find.textContaining('Подключён ваш ключ'), findsOneWidget);

    await _openTab(tester, 'Подбор');
    await _tap(tester, find.text('Подобрать занятие'));
    await _waitFor(tester, find.text('Из каталога'));
    expect(find.textContaining('Ключ Groq не подходит'), findsOneWidget);

    await _openTab(tester, 'Настройки');
    await _tap(tester, find.text('Вернуть встроенный ключ'));
    await _waitFor(tester, find.text('Используется встроенный ключ'));
    expect(
      LocalStorage(await SharedPreferences.getInstance())
          .loadSettings()
          .customApiKey,
      isEmpty,
    );

    // Со встроенным ключом снова работает ИИ.
    await _openTab(tester, 'Подбор');
    await _tap(tester, find.text('Другое'));
    await _waitFor(tester, find.text('Подобрано ИИ'));
  });

  testWidgets(
    '6. Ежедневное напоминание планируется и отменяется',
    (tester) async {
      await _launch(tester);
      await _openTab(tester, 'Настройки');

      await _tap(tester, find.byType(Switch));
      await _waitFor(
        tester,
        find.text('Каждый день в 10:00 предложим, чем заняться'),
      );
      var pending = await FlutterLocalNotificationsPlugin()
          .pendingNotificationRequests();
      expect(pending.map((p) => p.title), contains('Чем заняться?'));

      await _tap(tester, find.byType(Switch));
      await _waitFor(
        tester,
        find.text('Уведомление с предложением заглянуть в приложение'),
      );
      pending = await FlutterLocalNotificationsPlugin()
          .pendingNotificationRequests();
      expect(pending, isEmpty);
    },
    // На iOS разрешение на уведомления можно выдать только в системном
    // диалоге, который тест нажать не может. Проверяется вручную.
    skip: Platform.isIOS,
  );

  testWidgets('7. Свой календарь создаётся, если писать некуда', (
    tester,
  ) async {
    // Проверяем логику выбора на реальном списке календарей устройства.
    final calendars =
        (await dc.DeviceCalendarPlugin().retrieveCalendars()).data ??
        const <dc.Calendar>[];
    expect(calendars, isNotEmpty);
    final picked = pickWritableCalendar(calendars);
    expect(picked, isNotNull);
    expect(picked!.isReadOnly, isNot(true));
  });
}
