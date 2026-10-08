import '../core/russian_dates.dart';
import '../domain/schedule.dart';
import 'activity_generator.dart';

/// Собирает промпт для ИИ на русском языке.
String buildPrompt(ActivityRequest request) {
  final p = request.profile;
  final target = request.now.add(Duration(days: request.day.index));
  final lines = <String>[
    'Ты — помощник, который придумывает, чем заняться в свободное время.',
    'Предложи ОДНО конкретное и выполнимое занятие на '
        '${request.day.label.toLowerCase()} (${formatDayMonth(target)}, '
        '${weekdayName(target)}, ${seasonName(target)}).',
    if (p.name.isNotEmpty) 'Имя пользователя: ${p.name}.',
    if (p.city.isNotEmpty)
      'Город: ${p.city}. Учитывай реальные места и возможности этого города.',
    if (p.about.isNotEmpty) 'О себе: ${p.about}.',
    if (p.hobbies.isNotEmpty) 'Увлечения: ${p.hobbies.join(', ')}.',
    p.hasCar
        ? 'Есть машина — можно предлагать поездки за город.'
        : 'Машины нет — только пешком или на общественном транспорте.',
    'Бюджет: ${p.budget.label.toLowerCase()}.',
    if (request.day == ScheduleDay.today)
      'Сейчас ${request.now.hour}:00 — занятие должно успеть состояться сегодня.',
    if (request.excludeTitles.isNotEmpty)
      'Не предлагай это повторно: ${request.excludeTitles.join('; ')}.',
    'Иногда предлагай неожиданные, но приятные идеи (например, поехать кормить уток).',
    'Отвечай только на русском языке. Описание — 2–3 предложения, по делу.',
  ];
  return lines.join('\n');
}

/// JSON-схема ответа (structured output, strict-режим Groq).
const activityResponseSchema = {
  'type': 'object',
  'additionalProperties': false,
  'properties': {
    'title': {'type': 'string', 'description': 'Короткое название, до 6 слов'},
    'description': {'type': 'string'},
    'category': {
      'type': 'string',
      'description': 'Одно слово: Прогулка, Культура, Спорт, Природа, Еда…',
    },
    'emoji': {'type': 'string', 'description': 'Ровно один эмодзи'},
    'durationMinutes': {'type': 'integer'},
    'preferredStartHour': {'type': 'integer', 'description': 'Час начала 0–23'},
  },
  'required': [
    'title',
    'description',
    'category',
    'emoji',
    'durationMinutes',
    'preferredStartHour',
  ],
};
