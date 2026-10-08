import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/russian_dates.dart';
import '../../domain/activity.dart';
import '../../domain/schedule.dart';
import '../../state/providers.dart';
import '../../state/suggestion_controller.dart';
import '../theme.dart';
import '../widgets/common.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(suggestionControllerProvider);
    final controller = ref.read(suggestionControllerProvider.notifier);
    final name = ref.watch(profileProvider.select((p) => p.name.trim()));
    final now = ref.watch(clockProvider)();

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ScreenHeader(
            title: name.isEmpty ? 'Привет!' : 'Привет, $name!',
            subtitle: 'Нажмите кнопку — подберём, чем заняться.',
            trailing: DateBadge(text: formatHeaderDate(now)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: PillSelector<ScheduleDay>(
              values: ScheduleDay.values,
              selected: state.day,
              labelOf: (d) => d.label,
              onChanged: state.isBusy ? null : controller.selectDay,
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Panel(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: _PanelContent(
                    key: ValueKey(state.status),
                    state: state,
                    now: now,
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: _Actions(state: state, controller: controller),
          ),
        ],
      ),
    );
  }
}

class _PanelContent extends StatelessWidget {
  const _PanelContent({super.key, required this.state, required this.now});

  final SuggestionState state;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final activity = state.activity;
    return switch (state.status) {
      SuggestionStatus.idle => const _Placeholder(
        icon: SparkLogo(size: 72, color: AppColors.orange),
        text:
            'Здесь появится идея.\nПрофиль и город помогут подобрать '
            'точнее.',
      ),
      SuggestionStatus.loading => const _Placeholder(
        icon: SizedBox.square(
          dimension: 56,
          child: CircularProgressIndicator(
            color: AppColors.orange,
            strokeWidth: 5,
          ),
        ),
        text: 'Ищем, чем заняться…',
      ),
      SuggestionStatus.error => _Placeholder(
        icon: const Icon(
          Icons.cloud_off_rounded,
          size: 64,
          color: AppColors.textMuted,
        ),
        text: state.message ?? 'Что-то пошло не так.',
      ),
      SuggestionStatus.saved => _Saved(state: state),
      SuggestionStatus.ready ||
      SuggestionStatus.saving => SingleChildScrollView(
        child: Column(
          children: [
            if (state.message != null) _Notice(text: state.message!),
            ActivityCard(
              activity: activity!,
              fromAi: state.fromAi,
              slot: planSlot(
                now: now,
                day: state.day,
                preferredStartHour: activity.preferredStartHour,
                durationMinutes: activity.durationMinutes,
              ),
            ),
          ],
        ),
      ),
    };
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.icon, required this.text});

  final Widget icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon,
          const SizedBox(height: 20),
          Text(
            text,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(color: AppColors.textDark),
          ),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.sageLight,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: AppColors.orange,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: AppColors.textDark, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

/// Карточка занятия в стиле «Dev Meeting» с референса.
class ActivityCard extends StatelessWidget {
  const ActivityCard({
    super.key,
    required this.activity,
    required this.slot,
    required this.fromAi,
  });

  final Activity activity;
  final TimeSlot slot;
  final bool fromAi;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 78,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: const BoxDecoration(
                    color: AppColors.orange,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(AppRadii.card),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        formatTime(slot.start),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        formatDayMonth(slot.start),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          activity.category.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 11,
                            letterSpacing: 1,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          activity.title,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: AppColors.textDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 12, top: 10),
                  child: Text(
                    activity.emoji,
                    style: const TextStyle(fontSize: 34),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              activity.description,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: AppColors.textDark,
                height: 1.4,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _Tag(
                  icon: Icons.schedule_rounded,
                  text: formatDuration(activity.durationMinutes),
                ),
                _Tag(
                  icon: fromAi
                      ? Icons.auto_awesome_rounded
                      : Icons.menu_book_rounded,
                  text: fromAi ? 'Подобрано ИИ' : 'Из каталога',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.sageLight,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppColors.textMuted),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
          ),
        ],
      ),
    );
  }
}

class _Saved extends StatelessWidget {
  const _Saved({required this.state});

  final SuggestionState state;

  @override
  Widget build(BuildContext context) {
    final slot = state.savedSlot!;
    return _Placeholder(
      icon: Container(
        width: 84,
        height: 84,
        decoration: const BoxDecoration(
          color: AppColors.orange,
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.event_available_rounded,
          color: Colors.white,
          size: 44,
        ),
      ),
      text:
          '«${state.activity!.title}» в календаре!\n'
          '${formatHeaderDate(slot.start)}, ${formatTime(slot.start)}',
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({required this.state, required this.controller});

  final SuggestionState state;
  final SuggestionController controller;

  @override
  Widget build(BuildContext context) {
    switch (state.status) {
      case SuggestionStatus.ready || SuggestionStatus.saving:
        return Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: state.isBusy ? null : controller.suggest,
                child: const Text('Другое'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                onPressed: state.isBusy ? null : controller.accept,
                icon: state.status == SuggestionStatus.saving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_rounded),
                label: const Text('Согласиться'),
              ),
            ),
          ],
        );
      case SuggestionStatus.saved:
        return FilledButton(
          onPressed: () {
            controller.reset();
            controller.suggest();
          },
          child: const Text('Подобрать ещё'),
        );
      case SuggestionStatus.idle ||
          SuggestionStatus.loading ||
          SuggestionStatus.error:
        return FilledButton(
          onPressed: state.isBusy ? null : controller.suggest,
          child: Text(
            state.status == SuggestionStatus.error
                ? 'Попробовать снова'
                : 'Подобрать занятие',
          ),
        );
    }
  }
}
