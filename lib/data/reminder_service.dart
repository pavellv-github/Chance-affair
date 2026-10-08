import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

/// Ежедневные напоминания «Не знаешь, чем заняться?».
abstract interface class ReminderService {
  Future<void> init();

  /// Запрашивает разрешение на уведомления. true — разрешено.
  Future<bool> requestPermission();

  Future<void> scheduleDaily(int hour, int minute);

  Future<void> cancel();
}

/// Ближайший момент hh:mm в будущем относительно [now].
tz.TZDateTime nextInstanceOf(int hour, int minute, tz.TZDateTime now) {
  var at = tz.TZDateTime(
    now.location,
    now.year,
    now.month,
    now.day,
    hour,
    minute,
  );
  if (!at.isAfter(now)) {
    at = tz.TZDateTime(
      now.location,
      now.year,
      now.month,
      now.day + 1,
      hour,
      minute,
    );
  }
  return at;
}

/// Тексты напоминаний — меняем по дню, чтобы не надоедали.
const reminderMessages = [
  'Не знаете, чем заняться? Нажмите — подберём идею!',
  'Свободный вечер? Давайте придумаем что-нибудь интересное.',
  'Как насчёт небольшого приключения сегодня?',
  'Пора отвлечься от рутины — загляните за идеей.',
];

class LocalReminderService implements ReminderService {
  LocalReminderService([FlutterLocalNotificationsPlugin? plugin])
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const _notificationId = 1;
  static const _channelId = 'daily_ideas';

  final FlutterLocalNotificationsPlugin _plugin;

  @override
  Future<void> init() async {
    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
  }

  @override
  Future<bool> requestPermission() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      return await android.requestNotificationsPermission() ?? false;
    }
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (ios != null) {
      return await ios.requestPermissions(alert: true, sound: true) ?? false;
    }
    return false;
  }

  @override
  Future<void> scheduleDaily(int hour, int minute) async {
    await _plugin.cancel(_notificationId);
    final now = tz.TZDateTime.now(tz.local);
    await _plugin.zonedSchedule(
      _notificationId,
      'Чем заняться?',
      reminderMessages[now.weekday % reminderMessages.length],
      nextInstanceOf(hour, minute, now),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          'Идеи на день',
          channelDescription: 'Ежедневное предложение подобрать занятие',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      // Неточное время не требует отдельного разрешения на точные будильники.
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  @override
  Future<void> cancel() => _plugin.cancel(_notificationId);
}
