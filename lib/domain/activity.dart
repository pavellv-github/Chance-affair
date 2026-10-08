import 'package:flutter/foundation.dart';

/// Предложенное занятие.
@immutable
class Activity {
  const Activity({
    required this.title,
    required this.description,
    required this.category,
    this.durationMinutes = 120,
    this.preferredStartHour = 12,
    this.emoji = '✨',
  });

  final String title;
  final String description;
  final String category;
  final int durationMinutes;

  /// Рекомендуемый час начала (0–23).
  final int preferredStartHour;
  final String emoji;

  /// Разбирает ответ ИИ, подставляя безопасные значения для мусорных полей.
  factory Activity.fromJson(Map<String, Object?> json) {
    final title = (json['title'] as String?)?.trim() ?? '';
    final description = (json['description'] as String?)?.trim() ?? '';
    if (title.isEmpty || description.isEmpty) {
      throw const FormatException('В ответе нет названия или описания');
    }
    final emoji = (json['emoji'] as String?)?.trim() ?? '';
    final category = (json['category'] as String?)?.trim() ?? '';
    return Activity(
      title: title,
      description: description,
      category: category.isEmpty ? 'Разное' : category,
      durationMinutes: ((json['durationMinutes'] as num?)?.round() ?? 120)
          .clamp(15, 720),
      preferredStartHour: ((json['preferredStartHour'] as num?)?.round() ?? 12)
          .clamp(0, 23),
      emoji: emoji.isEmpty ? '✨' : emoji,
    );
  }

  Map<String, Object?> toJson() => {
    'title': title,
    'description': description,
    'category': category,
    'durationMinutes': durationMinutes,
    'preferredStartHour': preferredStartHour,
    'emoji': emoji,
  };

  @override
  bool operator ==(Object other) =>
      other is Activity &&
      other.title == title &&
      other.description == description &&
      other.category == category &&
      other.durationMinutes == durationMinutes &&
      other.preferredStartHour == preferredStartHour &&
      other.emoji == emoji;

  @override
  int get hashCode => Object.hash(
    title,
    description,
    category,
    durationMinutes,
    preferredStartHour,
    emoji,
  );
}
