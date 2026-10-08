import 'dart:math';

import 'package:chance_affair/data/activity_generator.dart';
import 'package:chance_affair/data/offline_activity_generator.dart';
import 'package:chance_affair/data/prompt_builder.dart';
import 'package:chance_affair/domain/schedule.dart';
import 'package:chance_affair/domain/user_profile.dart';
import 'package:flutter_test/flutter_test.dart';

ActivityRequest _req(
  UserProfile p, {
  List<String> exclude = const [],
  ScheduleDay day = ScheduleDay.today,
}) => ActivityRequest(
  profile: p,
  day: day,
  now: DateTime(2026, 10, 8, 9),
  excludeTitles: exclude,
);

Set<String> _carTitles() => OfflineActivityGenerator.catalog
    .where((e) => e.needsCar)
    .map((e) => e.activity.title)
    .toSet();

void main() {
  group('OfflineActivityGenerator', () {
    test('без машины не предлагает поездки', () async {
      final gen = OfflineActivityGenerator(random: Random(1));
      for (var i = 0; i < 50; i++) {
        final a = await gen.suggest(_req(const UserProfile()));
        expect(_carTitles(), isNot(contains(a.title)));
      }
    });

    test('с бюджетом «бесплатно» предлагает только бесплатное', () async {
      final paid = OfflineActivityGenerator.catalog
          .where((e) => !e.free)
          .map((e) => e.activity.title)
          .toSet();
      final gen = OfflineActivityGenerator(random: Random(2));
      for (var i = 0; i < 50; i++) {
        final a = await gen.suggest(
          _req(const UserProfile(budget: Budget.free, hasCar: true)),
        );
        expect(paid, isNot(contains(a.title)));
      }
    });

    test('не повторяет отклонённые идеи', () async {
      final all = OfflineActivityGenerator.catalog
          .map((e) => e.activity.title)
          .toList();
      final keep = all.first;
      final gen = OfflineActivityGenerator(random: Random(3));
      final a = await gen.suggest(
        _req(
          const UserProfile(hasCar: true),
          exclude: all.where((t) => t != keep).toList(),
        ),
      );
      expect(a.title, keep);
    });

    test('когда всё отклонено — начинает круг заново', () async {
      final all = OfflineActivityGenerator.catalog
          .map((e) => e.activity.title)
          .toList();
      final a = await OfflineActivityGenerator(random: Random(4))
          .suggest(_req(const UserProfile(hasCar: true), exclude: all));
      expect(all, contains(a.title));
    });

    test('чаще предлагает подходящее увлечениям', () async {
      final gen = OfflineActivityGenerator(random: Random(5));
      var cooking = 0;
      for (var i = 0; i < 100; i++) {
        final a = await gen.suggest(
          _req(const UserProfile(hobbies: ['Кулинария'])),
        );
        if (a.category == 'Еда') cooking++;
      }
      expect(cooking, greaterThan(50));
    });
  });

  group('buildPrompt', () {
    test('включает данные профиля и контекст дня', () {
      final prompt = buildPrompt(
        _req(
          const UserProfile(
            name: 'Павел',
            city: 'Самара',
            about: 'Люблю Волгу',
            hobbies: ['Рыбалка'],
            hasCar: true,
            budget: Budget.free,
          ),
          exclude: ['Кино'],
          day: ScheduleDay.tomorrow,
        ),
      );
      expect(prompt, contains('Самара'));
      expect(prompt, contains('Люблю Волгу'));
      expect(prompt, contains('Рыбалка'));
      expect(prompt, contains('Есть машина'));
      expect(prompt, contains('бесплатно'));
      expect(prompt, contains('Не предлагай это повторно: Кино'));
      expect(prompt, contains('9 октября'));
      expect(prompt, contains('пятница'));
      expect(prompt, contains('на русском'));
      expect(prompt, isNot(contains('Сейчас')));
    });

    test('для сегодняшнего дня учитывает текущее время', () {
      final prompt = buildPrompt(_req(const UserProfile()));
      expect(prompt, contains('Сейчас 9:00'));
      expect(prompt, contains('Машины нет'));
      expect(prompt, isNot(contains('Город')));
    });
  });
}
