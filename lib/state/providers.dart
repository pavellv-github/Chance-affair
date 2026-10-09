import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../data/activity_generator.dart';
import '../data/calendar_service.dart';
import '../data/feedback_service.dart';
import '../data/groq_activity_generator.dart';
import '../data/local_storage.dart';
import '../data/offline_activity_generator.dart';
import '../data/reminder_service.dart';
import '../domain/app_settings.dart';
import '../domain/user_profile.dart';

/// Подменяется в main() и в тестах.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPreferencesProvider не задан'),
);

final localStorageProvider = Provider(
  (ref) => LocalStorage(ref.watch(sharedPreferencesProvider)),
);

final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

final httpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

final calendarServiceProvider = Provider<CalendarService>(
  (ref) => DeviceCalendarService(),
);

final reminderServiceProvider = Provider<ReminderService>(
  (ref) => LocalReminderService(),
);

final feedbackServiceProvider = Provider<FeedbackService>(
  (ref) => FormSubmitFeedbackService(client: ref.watch(httpClientProvider)),
);

final offlineGeneratorProvider = Provider<ActivityGenerator>(
  (ref) => OfflineActivityGenerator(),
);

/// Ключ Groq, встроенный при сборке:
/// flutter build apk --dart-define-from-file=secrets.json
final builtInApiKeyProvider = Provider<String>(
  (ref) => const String.fromEnvironment('GROQ_API_KEY').trim(),
);

/// Действующий ключ: свой из настроек, иначе встроенный.
final apiKeyProvider = Provider<String>((ref) {
  final custom = ref.watch(
    settingsProvider.select((s) => s.customApiKey.trim()),
  );
  return custom.isNotEmpty ? custom : ref.watch(builtInApiKeyProvider);
});

/// ИИ-генератор; null, если ключа нет — тогда работает офлайн-каталог.
final aiGeneratorProvider = Provider<ActivityGenerator?>((ref) {
  final key = ref.watch(apiKeyProvider);
  if (key.isEmpty) return null;
  return GroqActivityGenerator(
    client: ref.watch(httpClientProvider),
    apiKey: key,
  );
});

final profileProvider = NotifierProvider<ProfileNotifier, UserProfile>(
  ProfileNotifier.new,
);

class ProfileNotifier extends Notifier<UserProfile> {
  @override
  UserProfile build() => ref.watch(localStorageProvider).loadProfile();

  Future<void> save(UserProfile profile) async {
    state = profile;
    await ref.read(localStorageProvider).saveProfile(profile);
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(
  SettingsNotifier.new,
);

class SettingsNotifier extends Notifier<AppSettings> {
  @override
  AppSettings build() => ref.watch(localStorageProvider).loadSettings();

  Future<void> update(AppSettings settings) async {
    state = settings;
    await ref.read(localStorageProvider).saveSettings(settings);
  }

  /// Включает/выключает напоминания. Возвращает false, если пользователь
  /// не дал разрешение на уведомления.
  Future<bool> setRemindersEnabled(bool enabled) async {
    final reminders = ref.read(reminderServiceProvider);
    if (enabled) {
      if (!await reminders.requestPermission()) return false;
      await reminders.scheduleDaily(state.reminderHour, state.reminderMinute);
    } else {
      await reminders.cancel();
    }
    await update(state.copyWith(remindersEnabled: enabled));
    return true;
  }

  Future<void> setReminderTime(int hour, int minute) async {
    await update(state.copyWith(reminderHour: hour, reminderMinute: minute));
    if (state.remindersEnabled) {
      await ref.read(reminderServiceProvider).scheduleDaily(hour, minute);
    }
  }
}
