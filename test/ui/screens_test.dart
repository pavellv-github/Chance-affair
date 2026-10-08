import 'package:chance_affair/app.dart';
import 'package:chance_affair/data/calendar_service.dart';
import 'package:chance_affair/data/local_storage.dart';
import 'package:chance_affair/domain/activity.dart';
import 'package:chance_affair/ui/profile/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/fakes.dart';

Future<SharedPreferences> _prefs([Map<String, Object> values = const {}]) {
  SharedPreferences.setMockInitialValues(values);
  return SharedPreferences.getInstance();
}

Future<void> _pumpApp(
  WidgetTester tester,
  SharedPreferences sp, {
  FakeCalendar? calendar,
  FakeReminders? reminders,
  FakeGenerator? offline,
  String builtInKey = '',
}) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: overridesFor(
        sp,
        calendar: calendar,
        reminders: reminders,
        offline: offline,
        builtInKey: builtInKey,
      ),
      child: const ChanceAffairApp(),
    ),
  );
  await tester.pumpAndSettle();
}

/// Прокручивает к элементу и нажимает на него.
Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('главный экран: приветствие, дата и вкладки на русском', (
    tester,
  ) async {
    await _pumpApp(
      tester,
      await _prefs({'user_profile_v1': '{"name":"Павел"}'}),
    );

    expect(find.text('Привет, Павел!'), findsOneWidget);
    expect(find.text('Четверг, 8 октября'), findsOneWidget);
    expect(find.text('Подбор'), findsOneWidget);
    expect(find.text('Профиль'), findsOneWidget);
    expect(find.text('Настройки'), findsOneWidget);
    expect(find.text('Подобрать занятие'), findsOneWidget);
  });

  testWidgets('подбор → карточка → «Согласиться» → запись в календарь', (
    tester,
  ) async {
    final calendar = FakeCalendar();
    await _pumpApp(tester, await _prefs(), calendar: calendar);

    await tester.tap(find.text('Завтра'));
    await tester.tap(find.text('Подобрать занятие'));
    await tester.pumpAndSettle();

    expect(find.text('Покормить уток'), findsOneWidget);
    expect(find.text('15:00'), findsOneWidget);
    expect(find.text('9 октября'), findsOneWidget);
    expect(find.text('1 ч 30 мин'), findsOneWidget);
    expect(find.text('Из каталога'), findsOneWidget);

    await tester.tap(find.text('Согласиться'));
    await tester.pumpAndSettle();

    expect(calendar.events.single.start, DateTime(2026, 10, 9, 15));
    expect(find.textContaining('в календаре!'), findsOneWidget);
    expect(find.text('Подобрать ещё'), findsOneWidget);
  });

  testWidgets('«Другое» подбирает новую идею', (tester) async {
    final offline = FakeGenerator([
      sampleActivity,
      const Activity(
        title: 'Музей',
        description: 'Сходить',
        category: 'Культура',
      ),
    ]);
    await _pumpApp(tester, await _prefs(), offline: offline);

    await tester.tap(find.text('Подобрать занятие'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Другое'));
    await tester.pumpAndSettle();

    expect(find.text('Музей'), findsOneWidget);
    expect(offline.requests.last.excludeTitles, ['Покормить уток']);
  });

  testWidgets('ошибка календаря показывается на карточке', (tester) async {
    await _pumpApp(
      tester,
      await _prefs(),
      calendar: FakeCalendar(error: const CalendarException('Нет доступа')),
    );

    await tester.tap(find.text('Подобрать занятие'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Согласиться'));
    await tester.pumpAndSettle();

    expect(find.text('Нет доступа'), findsOneWidget);
    expect(find.text('Согласиться'), findsOneWidget);
  });

  testWidgets('профиль сохраняется на устройство', (tester) async {
    final sp = await _prefs();
    await _pumpApp(tester, sp);

    await tester.tap(find.text('Профиль'));
    await tester.pumpAndSettle();
    expect(find.text('Ваш профиль'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'Имя'), 'Анна');
    await tester.enterText(find.widgetWithText(TextField, 'Город'), 'Тверь');
    await _tapVisible(tester, find.text('Музеи'));
    await tester.enterText(
      find.widgetWithText(TextField, 'Своё увлечение'),
      'Рыбалка',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await _tapVisible(tester, find.text('Есть машина'));
    await _tapVisible(tester, find.text('Бесплатно'));
    await tester.pumpAndSettle();
    await _tapVisible(tester, find.text('Сохранить'));
    await tester.pumpAndSettle();

    expect(find.text('Профиль сохранён'), findsOneWidget);
    final saved = LocalStorage(sp).loadProfile();
    expect(saved.name, 'Анна');
    expect(saved.city, 'Тверь');
    expect(saved.hobbies, ['Музеи', 'Рыбалка']);
    expect(saved.hasCar, isTrue);

    // Приветствие на главной обновилось.
    await tester.tap(find.text('Подбор'));
    await tester.pumpAndSettle();
    expect(find.text('Привет, Анна!'), findsOneWidget);
  });

  testWidgets('настройки: включение напоминаний и свой ключ Groq', (
    tester,
  ) async {
    final sp = await _prefs();
    final reminders = FakeReminders();
    await _pumpApp(tester, sp, reminders: reminders);

    await tester.tap(find.text('Настройки'));
    await tester.pumpAndSettle();
    expect(find.text('Напоминания'), findsOneWidget);
    expect(find.text('Время напоминания'), findsNothing);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(reminders.scheduled, (hour: 10, minute: 0));
    expect(
      find.text('Каждый день в 10:00 предложим, чем заняться'),
      findsOneWidget,
    );
    expect(find.text('Время напоминания'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, 'Новый ключ (gsk_…)'),
      'gsk_test',
    );
    await _tapVisible(tester, find.text('Обновить ключ'));
    expect(find.text('Ключ обновлён'), findsOneWidget);
    expect(LocalStorage(sp).loadSettings().customApiKey, 'gsk_test');
    expect(find.textContaining('Подключён ваш ключ'), findsOneWidget);
  });

  testWidgets('без разрешения на уведомления — подсказка', (tester) async {
    await _pumpApp(
      tester,
      await _prefs(),
      reminders: FakeReminders(permission: false),
    );
    await tester.tap(find.text('Настройки'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(
      find.text('Разрешите уведомления в настройках телефона.'),
      findsOneWidget,
    );
    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
  });

  testWidgets('ключ Groq: встроенный, обновление и возврат к встроенному', (
    tester,
  ) async {
    final sp = await _prefs();
    await _pumpApp(tester, sp, builtInKey: 'gsk_built_in');
    await tester.tap(find.text('Настройки'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Подключён встроенный ключ'), findsOneWidget);
    expect(find.text('Вернуть встроенный ключ'), findsNothing);

    // Пустое поле — просим вставить ключ, ничего не сохраняем.
    await _tapVisible(tester, find.text('Обновить ключ'));
    expect(find.text('Вставьте новый ключ'), findsOneWidget);
    expect(LocalStorage(sp).loadSettings().customApiKey, isEmpty);

    await tester.enterText(
      find.widgetWithText(TextField, 'Новый ключ (gsk_…)'),
      'gsk_new',
    );
    await _tapVisible(tester, find.text('Обновить ключ'));
    expect(find.textContaining('Подключён ваш ключ'), findsOneWidget);

    await _tapVisible(tester, find.text('Вернуть встроенный ключ'));
    expect(find.text('Используется встроенный ключ'), findsOneWidget);
    expect(find.textContaining('Подключён встроенный ключ'), findsOneWidget);
    expect(LocalStorage(sp).loadSettings().customApiKey, isEmpty);
  });

  testWidgets('подсказка скрывается при переключении вкладок', (tester) async {
    await _pumpApp(tester, await _prefs());
    await tester.tap(find.text('Профиль'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Сохранить'),
      300,
      scrollable: find
          .descendant(
            of: find.byType(ProfileScreen),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await _tapVisible(tester, find.text('Сохранить'));
    expect(find.text('Профиль сохранён'), findsOneWidget);

    await tester.tap(find.text('Подбор'));
    await tester.pumpAndSettle();
    expect(find.text('Профиль сохранён'), findsNothing);
  });
}
