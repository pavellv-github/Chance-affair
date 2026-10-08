import 'package:flutter/foundation.dart';

import 'schedule.dart';

/// Настройки приложения. Хранятся только на устройстве.
@immutable
class AppSettings {
  const AppSettings({
    this.customApiKey = '',
    this.defaultDay = ScheduleDay.today,
    this.remindersEnabled = false,
    this.reminderHour = 10,
    this.reminderMinute = 0,
  });

  static const defaults = AppSettings();

  /// Свой ключ Groq. Пустой — используется ключ, встроенный в сборку.
  final String customApiKey;
  final ScheduleDay defaultDay;

  /// Ежедневное напоминание «Не знаешь, чем заняться?».
  final bool remindersEnabled;
  final int reminderHour;
  final int reminderMinute;

  bool get hasCustomKey => customApiKey.trim().isNotEmpty;

  AppSettings copyWith({
    String? customApiKey,
    ScheduleDay? defaultDay,
    bool? remindersEnabled,
    int? reminderHour,
    int? reminderMinute,
  }) {
    return AppSettings(
      customApiKey: customApiKey ?? this.customApiKey,
      defaultDay: defaultDay ?? this.defaultDay,
      remindersEnabled: remindersEnabled ?? this.remindersEnabled,
      reminderHour: reminderHour ?? this.reminderHour,
      reminderMinute: reminderMinute ?? this.reminderMinute,
    );
  }

  Map<String, Object?> toJson() => {
    'groqApiKey': customApiKey,
    'defaultDay': defaultDay.name,
    'remindersEnabled': remindersEnabled,
    'reminderHour': reminderHour,
    'reminderMinute': reminderMinute,
  };

  factory AppSettings.fromJson(Map<String, Object?> json) {
    return AppSettings(
      customApiKey: json['groqApiKey'] as String? ?? '',
      defaultDay: ScheduleDay.values.firstWhere(
        (d) => d.name == json['defaultDay'],
        orElse: () => ScheduleDay.today,
      ),
      remindersEnabled: json['remindersEnabled'] as bool? ?? false,
      reminderHour: ((json['reminderHour'] as num?)?.toInt() ?? 10).clamp(
        0,
        23,
      ),
      reminderMinute: ((json['reminderMinute'] as num?)?.toInt() ?? 0).clamp(
        0,
        59,
      ),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AppSettings &&
      other.customApiKey == customApiKey &&
      other.defaultDay == defaultDay &&
      other.remindersEnabled == remindersEnabled &&
      other.reminderHour == reminderHour &&
      other.reminderMinute == reminderMinute;

  @override
  int get hashCode => Object.hash(
    customApiKey,
    defaultDay,
    remindersEnabled,
    reminderHour,
    reminderMinute,
  );
}
