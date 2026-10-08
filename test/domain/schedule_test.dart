import 'package:chance_affair/core/russian_dates.dart';
import 'package:chance_affair/domain/schedule.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('planSlot', () {
    test('сегодня, рекомендуемый час ещё впереди', () {
      final slot = planSlot(
        now: DateTime(2026, 10, 8, 9, 30),
        day: ScheduleDay.today,
        preferredStartHour: 15,
        durationMinutes: 90,
      );
      expect(slot.start, DateTime(2026, 10, 8, 15));
      expect(slot.end, DateTime(2026, 10, 8, 16, 30));
    });

    test('сегодня, рекомендуемый час прошёл — ближайший полный час', () {
      final slot = planSlot(
        now: DateTime(2026, 10, 8, 16, 20),
        day: ScheduleDay.today,
        preferredStartHour: 10,
        durationMinutes: 60,
      );
      expect(slot.start, DateTime(2026, 10, 8, 17));
    });

    test('сегодня, уже поздно — переносим на завтра', () {
      final slot = planSlot(
        now: DateTime(2026, 10, 8, 22, 40),
        day: ScheduleDay.today,
        preferredStartHour: 11,
        durationMinutes: 60,
      );
      expect(slot.start, DateTime(2026, 10, 9, 11));
    });

    test('завтра — рекомендуемый час следующего дня, через границу месяца', () {
      final slot = planSlot(
        now: DateTime(2026, 10, 31, 20),
        day: ScheduleDay.tomorrow,
        preferredStartHour: 12,
        durationMinutes: 120,
      );
      expect(slot.start, DateTime(2026, 11, 1, 12));
      expect(slot.end, DateTime(2026, 11, 1, 14));
    });
  });

  group('русские даты', () {
    final d = DateTime(2026, 10, 8, 9, 5);

    test('формат дня и времени', () {
      expect(formatDayMonth(d), '8 октября');
      expect(formatHeaderDate(d), 'Четверг, 8 октября');
      expect(formatTime(d), '09:05');
    });

    test('времена года', () {
      expect(seasonName(DateTime(2026, 1, 1)), 'зима');
      expect(seasonName(DateTime(2026, 4, 1)), 'весна');
      expect(seasonName(DateTime(2026, 7, 1)), 'лето');
      expect(seasonName(d), 'осень');
    });

    test('длительность', () {
      expect(formatDuration(45), '45 мин');
      expect(formatDuration(120), '2 ч');
      expect(formatDuration(90), '1 ч 30 мин');
    });
  });
}
