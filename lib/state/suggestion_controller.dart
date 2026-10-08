import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/activity_generator.dart';
import '../data/calendar_service.dart';
import '../domain/activity.dart';
import '../domain/schedule.dart';
import 'providers.dart';

enum SuggestionStatus { idle, loading, ready, saving, saved, error }

@immutable
class SuggestionState {
  const SuggestionState({
    this.status = SuggestionStatus.idle,
    this.day = ScheduleDay.today,
    this.activity,
    this.message,
    this.savedSlot,
    this.fromAi = false,
    this.rejected = const [],
  });

  final SuggestionStatus status;
  final ScheduleDay day;
  final Activity? activity;

  /// Ошибка или пояснение для пользователя.
  final String? message;
  final TimeSlot? savedSlot;

  /// true — идею придумал ИИ, false — встроенный каталог.
  final bool fromAi;

  /// Отклонённые идеи, чтобы не повторяться.
  final List<String> rejected;

  bool get isBusy =>
      status == SuggestionStatus.loading || status == SuggestionStatus.saving;

  SuggestionState copyWith({
    SuggestionStatus? status,
    ScheduleDay? day,
    Activity? activity,
    String? message,
    TimeSlot? savedSlot,
    bool? fromAi,
    List<String>? rejected,
    bool clearMessage = false,
  }) {
    return SuggestionState(
      status: status ?? this.status,
      day: day ?? this.day,
      activity: activity ?? this.activity,
      message: clearMessage ? null : message ?? this.message,
      savedSlot: savedSlot ?? this.savedSlot,
      fromAi: fromAi ?? this.fromAi,
      rejected: rejected ?? this.rejected,
    );
  }
}

final suggestionControllerProvider =
    NotifierProvider<SuggestionController, SuggestionState>(
      SuggestionController.new,
    );

class SuggestionController extends Notifier<SuggestionState> {
  /// Сколько последних отклонённых идей передаём в промпт.
  static const maxRejected = 15;

  @override
  SuggestionState build() =>
      SuggestionState(day: ref.read(settingsProvider).defaultDay);

  void selectDay(ScheduleDay day) {
    if (state.isBusy) return;
    state = state.copyWith(day: day);
  }

  /// Подобрать занятие (или подобрать другое, если текущее не подошло).
  Future<void> suggest() async {
    if (state.isBusy) return;
    final previous = state.activity;
    final rejected = [
      ...state.rejected,
      if (previous != null && state.status == SuggestionStatus.ready)
        previous.title,
    ];
    final trimmed = rejected.length > maxRejected
        ? rejected.sublist(rejected.length - maxRejected)
        : rejected;

    state = state.copyWith(
      status: SuggestionStatus.loading,
      rejected: trimmed,
      clearMessage: true,
    );

    final request = ActivityRequest(
      profile: ref.read(profileProvider),
      day: state.day,
      now: ref.read(clockProvider)(),
      excludeTitles: trimmed,
    );

    final ai = ref.read(aiGeneratorProvider);
    String? notice;
    if (ai != null) {
      try {
        final activity = await ai.suggest(request);
        if (!ref.mounted) return;
        state = state.copyWith(
          status: SuggestionStatus.ready,
          activity: activity,
          fromAi: true,
        );
        return;
      } on ActivityGenerationException catch (e) {
        notice = '${e.message} Пока — идея из встроенного каталога.';
      } on Object {
        notice = 'ИИ недоступен. Пока — идея из встроенного каталога.';
      }
    }

    try {
      final activity = await ref
          .read(offlineGeneratorProvider)
          .suggest(request);
      if (!ref.mounted) return;
      state = state.copyWith(
        status: SuggestionStatus.ready,
        activity: activity,
        fromAi: false,
        message: notice,
      );
    } on Object {
      if (!ref.mounted) return;
      state = state.copyWith(
        status: SuggestionStatus.error,
        message: 'Не получилось ничего подобрать. Попробуйте ещё раз.',
      );
    }
  }

  /// Согласиться: записать занятие в календарь телефона.
  Future<void> accept() async {
    final activity = state.activity;
    if (activity == null || state.isBusy) return;

    final slot = planSlot(
      now: ref.read(clockProvider)(),
      day: state.day,
      preferredStartHour: activity.preferredStartHour,
      durationMinutes: activity.durationMinutes,
    );
    state = state.copyWith(status: SuggestionStatus.saving, clearMessage: true);

    try {
      await ref
          .read(calendarServiceProvider)
          .addEvent(
            title: '${activity.emoji} ${activity.title}',
            description: activity.description,
            start: slot.start,
            end: slot.end,
          );
      if (!ref.mounted) return;
      state = state.copyWith(status: SuggestionStatus.saved, savedSlot: slot);
    } on CalendarException catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(
        status: SuggestionStatus.ready,
        message: e.message,
      );
    } on Object {
      if (!ref.mounted) return;
      state = state.copyWith(
        status: SuggestionStatus.ready,
        message: 'Не удалось записать событие в календарь.',
      );
    }
  }

  /// Начать заново после сохранения.
  void reset() {
    state = SuggestionState(day: state.day);
  }
}
