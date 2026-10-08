const _months = [
  'января',
  'февраля',
  'марта',
  'апреля',
  'мая',
  'июня',
  'июля',
  'августа',
  'сентября',
  'октября',
  'ноября',
  'декабря',
];

const _weekdays = [
  'понедельник',
  'вторник',
  'среда',
  'четверг',
  'пятница',
  'суббота',
  'воскресенье',
];

/// «8 октября»
String formatDayMonth(DateTime d) => '${d.day} ${_months[d.month - 1]}';

/// «четверг»
String weekdayName(DateTime d) => _weekdays[d.weekday - 1];

/// «09:05»
String formatTime(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

/// «Четверг, 8 октября»
String formatHeaderDate(DateTime d) {
  final w = weekdayName(d);
  return '${w[0].toUpperCase()}${w.substring(1)}, ${formatDayMonth(d)}';
}

/// «осень»
String seasonName(DateTime d) => switch (d.month) {
  12 || 1 || 2 => 'зима',
  3 || 4 || 5 => 'весна',
  6 || 7 || 8 => 'лето',
  _ => 'осень',
};

/// «1 ч 30 мин», «45 мин», «2 ч»
String formatDuration(int minutes) {
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h == 0) return '$m мин';
  if (m == 0) return '$h ч';
  return '$h ч $m мин';
}
