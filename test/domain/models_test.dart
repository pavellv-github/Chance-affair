import 'package:chance_affair/domain/activity.dart';
import 'package:chance_affair/domain/app_settings.dart';
import 'package:chance_affair/domain/schedule.dart';
import 'package:chance_affair/domain/user_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UserProfile', () {
    test('сериализуется и восстанавливается без потерь', () {
      const profile = UserProfile(
        name: 'Павел',
        city: 'Казань',
        about: 'Люблю тишину',
        hobbies: ['Музеи', 'Фото'],
        hasCar: true,
        budget: Budget.low,
      );
      expect(UserProfile.fromJson(profile.toJson()), profile);
    });

    test('пустой JSON даёт профиль по умолчанию', () {
      expect(UserProfile.fromJson({}), UserProfile.empty);
    });

    test('неизвестный бюджет превращается в «Не важно»', () {
      expect(UserProfile.fromJson({'budget': 'luxury'}).budget, Budget.any);
    });

    test('copyWith меняет только переданные поля', () {
      const p = UserProfile(name: 'А', city: 'Б');
      final c = p.copyWith(city: 'В');
      expect(c.name, 'А');
      expect(c.city, 'В');
    });
  });

  group('AppSettings', () {
    test('сериализуется и восстанавливается без потерь', () {
      const s = AppSettings(
        customApiKey: 'key',
        defaultDay: ScheduleDay.tomorrow,
        remindersEnabled: true,
        reminderHour: 19,
        reminderMinute: 45,
      );
      expect(AppSettings.fromJson(s.toJson()), s);
    });

    test('ограничивает некорректное время', () {
      final s = AppSettings.fromJson({
        'reminderHour': 40,
        'reminderMinute': -3,
      });
      expect(s.reminderHour, 23);
      expect(s.reminderMinute, 0);
    });

    test('hasCustomKey игнорирует пробелы', () {
      expect(const AppSettings(customApiKey: '   ').hasCustomKey, isFalse);
      expect(const AppSettings(customApiKey: 'abc').hasCustomKey, isTrue);
    });
  });

  group('Activity.fromJson', () {
    test('разбирает корректный ответ', () {
      final a = Activity.fromJson({
        'title': ' Музей ',
        'description': 'Сходить в музей',
        'category': 'Культура',
        'emoji': '🏛️',
        'durationMinutes': 150,
        'preferredStartHour': 12,
      });
      expect(a.title, 'Музей');
      expect(a.durationMinutes, 150);
    });

    test('подставляет значения по умолчанию и ограничивает диапазоны', () {
      final a = Activity.fromJson({
        'title': 'Прогулка',
        'description': 'Пройтись',
        'durationMinutes': 5000,
        'preferredStartHour': 30,
      });
      expect(a.category, 'Разное');
      expect(a.emoji, '✨');
      expect(a.durationMinutes, 720);
      expect(a.preferredStartHour, 23);
    });

    test('без названия — FormatException', () {
      expect(
        () => Activity.fromJson({'description': 'x'}),
        throwsFormatException,
      );
    });
  });
}
