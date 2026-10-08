import '../domain/activity.dart';
import '../domain/schedule.dart';
import '../domain/user_profile.dart';

/// Запрос на подбор занятия.
class ActivityRequest {
  const ActivityRequest({
    required this.profile,
    required this.day,
    required this.now,
    this.excludeTitles = const [],
  });

  final UserProfile profile;
  final ScheduleDay day;
  final DateTime now;

  /// Уже предложенные и отклонённые занятия — их не повторяем.
  final List<String> excludeTitles;
}

/// Источник идей для занятий.
abstract interface class ActivityGenerator {
  Future<Activity> suggest(ActivityRequest request);
}

/// Ошибка подбора с понятным пользователю текстом.
class ActivityGenerationException implements Exception {
  const ActivityGenerationException(this.message);

  final String message;

  @override
  String toString() => message;
}
