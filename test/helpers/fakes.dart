import 'package:chance_affair/data/activity_generator.dart';
import 'package:chance_affair/data/calendar_service.dart';
import 'package:chance_affair/data/feedback_service.dart';
import 'package:chance_affair/data/reminder_service.dart';
import 'package:chance_affair/domain/activity.dart';
import 'package:chance_affair/state/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:shared_preferences/shared_preferences.dart';

const sampleActivity = Activity(
  title: 'Покормить уток',
  description: 'Съездите к пруду и покормите уток овсянкой.',
  category: 'Природа',
  emoji: '🦆',
  durationMinutes: 90,
  preferredStartHour: 15,
);

/// Генератор, возвращающий заранее заданные ответы по очереди.
class FakeGenerator implements ActivityGenerator {
  FakeGenerator(this.results);

  /// Activity или Exception.
  final List<Object> results;
  final requests = <ActivityRequest>[];

  @override
  Future<Activity> suggest(ActivityRequest request) async {
    requests.add(request);
    final next = results.length > 1 ? results.removeAt(0) : results.first;
    if (next is Activity) return next;
    throw next;
  }
}

class FakeCalendar implements CalendarService {
  FakeCalendar({this.error});

  final Exception? error;
  final events = <({String title, DateTime start, DateTime end})>[];

  @override
  Future<String> addEvent({
    required String title,
    required String description,
    required DateTime start,
    required DateTime end,
  }) async {
    if (error != null) throw error!;
    events.add((title: title, start: start, end: end));
    return 'event-${events.length}';
  }
}

class FakeReminders implements ReminderService {
  FakeReminders({this.permission = true});

  bool permission;
  ({int hour, int minute})? scheduled;
  int cancelCalls = 0;

  @override
  Future<void> init() async {}

  @override
  Future<bool> requestPermission() async => permission;

  @override
  Future<void> scheduleDaily(int hour, int minute) async {
    scheduled = (hour: hour, minute: minute);
  }

  @override
  Future<void> cancel() async {
    cancelCalls++;
    scheduled = null;
  }
}

class FakeFeedback implements FeedbackService {
  FakeFeedback({this.error});

  final Exception? error;
  final sent = <({String message, String name, String email})>[];

  @override
  Future<void> send({
    required String message,
    String name = '',
    String email = '',
  }) async {
    if (error != null) throw error!;
    sent.add((message: message, name: name, email: email));
  }
}

/// 8 октября 2026, 9:30.
final fixedNow = DateTime(2026, 10, 8, 9, 30);

Future<ProviderContainer> makeContainer({
  Map<String, Object> prefs = const {},
  ActivityGenerator? ai,
  ActivityGenerator? offline,
  CalendarService? calendar,
  ReminderService? reminders,
  DateTime? now,
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final sp = await SharedPreferences.getInstance();
  return ProviderContainer.test(
    overrides: overridesFor(
      sp,
      ai: ai,
      offline: offline,
      calendar: calendar,
      reminders: reminders,
      now: now,
    ),
  );
}

List<Override> overridesFor(
  SharedPreferences sp, {
  ActivityGenerator? ai,
  ActivityGenerator? offline,
  CalendarService? calendar,
  ReminderService? reminders,
  FeedbackService? feedback,
  DateTime? now,
  String builtInKey = '',
}) {
  return [
    builtInApiKeyProvider.overrideWithValue(builtInKey),
    sharedPreferencesProvider.overrideWithValue(sp),
    clockProvider.overrideWithValue(() => now ?? fixedNow),
    aiGeneratorProvider.overrideWithValue(ai),
    offlineGeneratorProvider.overrideWithValue(
      offline ?? FakeGenerator([sampleActivity]),
    ),
    calendarServiceProvider.overrideWithValue(calendar ?? FakeCalendar()),
    reminderServiceProvider.overrideWithValue(reminders ?? FakeReminders()),
    feedbackServiceProvider.overrideWithValue(feedback ?? FakeFeedback()),
  ];
}
