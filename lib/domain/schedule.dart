/// На какой день записать занятие.
enum ScheduleDay {
  today('Сегодня'),
  tomorrow('Завтра');

  const ScheduleDay(this.label);

  final String label;
}

/// Временной слот занятия в календаре.
class TimeSlot {
  const TimeSlot(this.start, this.end);

  final DateTime start;
  final DateTime end;
}

/// Подбирает время начала: рекомендуемый час выбранного дня.
/// Если сегодня этот час уже прошёл — ближайший следующий полный час
/// (но не позже 22:00, иначе — переносим на завтра).
TimeSlot planSlot({
  required DateTime now,
  required ScheduleDay day,
  required int preferredStartHour,
  required int durationMinutes,
}) {
  final today = DateTime(now.year, now.month, now.day);
  var start = switch (day) {
    ScheduleDay.today => today.add(Duration(hours: preferredStartHour)),
    ScheduleDay.tomorrow => DateTime(
      today.year,
      today.month,
      today.day + 1,
      preferredStartHour,
    ),
  };

  if (day == ScheduleDay.today && !start.isAfter(now)) {
    final nextHour = DateTime(now.year, now.month, now.day, now.hour + 1);
    start = nextHour.hour <= 22 && nextHour.day == now.day
        ? nextHour
        : DateTime(today.year, today.month, today.day + 1, preferredStartHour);
  }

  return TimeSlot(start, start.add(Duration(minutes: durationMinutes)));
}
