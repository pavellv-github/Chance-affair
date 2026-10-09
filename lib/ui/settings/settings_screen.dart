import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/app_settings.dart';
import '../../domain/schedule.dart';
import '../../state/providers.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'feedback_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late final TextEditingController _apiKey;
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    _apiKey = TextEditingController();
  }

  @override
  void dispose() {
    _apiKey.dispose();
    super.dispose();
  }

  void _toast(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _toggleReminders(bool enabled) async {
    final ok = await ref
        .read(settingsProvider.notifier)
        .setRemindersEnabled(enabled);
    if (!mounted) return;
    if (!ok) {
      _toast('Разрешите уведомления в настройках телефона.');
    }
  }

  Future<void> _pickTime() async {
    final s = ref.read(settingsProvider);
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: s.reminderHour, minute: s.reminderMinute),
      helpText: 'Время напоминания',
      cancelText: 'Отмена',
      confirmText: 'Готово',
    );
    if (picked == null) return;
    await ref
        .read(settingsProvider.notifier)
        .setReminderTime(picked.hour, picked.minute);
  }

  Future<void> _updateKey() async {
    final key = _apiKey.text.trim();
    if (key.isEmpty) {
      _toast('Вставьте новый ключ');
      return;
    }
    FocusScope.of(context).unfocus();
    await _setCustomKey(key);
    _apiKey.clear();
    if (mounted) _toast('Ключ обновлён');
  }

  Future<void> _resetKey() async {
    await _setCustomKey('');
    if (!mounted) return;
    _toast(
      ref.read(builtInApiKeyProvider).isEmpty
          ? 'Свой ключ удалён — идеи будут из встроенного каталога'
          : 'Используется встроенный ключ',
    );
  }

  Future<void> _setCustomKey(String key) => ref
      .read(settingsProvider.notifier)
      .update(ref.read(settingsProvider).copyWith(customApiKey: key));

  String _aiStatus(AppSettings s, bool hasBuiltIn) {
    if (s.hasCustomKey) return 'Подключён ваш ключ — идеи придумывает ИИ';
    if (hasBuiltIn) return 'Подключён встроенный ключ — идеи придумывает ИИ';
    return 'Не подключён — идеи берутся из встроенного каталога. '
        'Бесплатный ключ: console.groq.com/keys';
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(settingsProvider);
    final hasBuiltIn = ref.watch(builtInApiKeyProvider).isNotEmpty;
    final time = TimeOfDay(hour: s.reminderHour, minute: s.reminderMinute);
    final timeText =
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          const ScreenHeader(
            title: 'Настройки',
            subtitle: 'Напоминания, подбор и подключение ИИ.',
          ),
          _SettingRow(
            title: 'Напоминания',
            subtitle: s.remindersEnabled
                ? 'Каждый день в $timeText предложим, чем заняться'
                : 'Уведомление с предложением заглянуть в приложение',
            trailing: Switch(
              value: s.remindersEnabled,
              onChanged: _toggleReminders,
            ),
          ),
          if (s.remindersEnabled)
            _SettingRow(
              title: 'Время напоминания',
              subtitle: timeText,
              onTap: _pickTime,
              trailing: const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.onInk,
              ),
            ),
          _SettingRow(
            title: 'День по умолчанию',
            subtitle: 'На какой день записывать занятие',
            below: PillSelector<ScheduleDay>(
              values: ScheduleDay.values,
              selected: s.defaultDay,
              labelOf: (d) => d.label,
              onChanged: (d) => ref
                  .read(settingsProvider.notifier)
                  .update(s.copyWith(defaultDay: d)),
            ),
          ),
          _SettingRow(
            title: 'ИИ Groq',
            subtitle: _aiStatus(s, hasBuiltIn),
            below: Column(
              children: [
                TextField(
                  controller: _apiKey,
                  obscureText: _obscure,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: InputDecoration(
                    hintText: 'Новый ключ (gsk_…)',
                    suffixIcon: IconButton(
                      tooltip: _obscure ? 'Показать ключ' : 'Скрыть ключ',
                      icon: Icon(
                        _obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _updateKey,
                  child: const Text('Обновить ключ'),
                ),
                if (s.hasCustomKey) ...[
                  const SizedBox(height: 4),
                  TextButton(
                    onPressed: _resetKey,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.onInkMuted,
                    ),
                    child: Text(
                      hasBuiltIn
                          ? 'Вернуть встроенный ключ'
                          : 'Удалить свой ключ',
                    ),
                  ),
                ],
              ],
            ),
          ),
          _SettingRow(
            title: 'Обратная связь',
            subtitle: 'Написать разработчику',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const FeedbackScreen()),
            ),
            trailing: const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.onInk,
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 24, 24, 0),
            child: Text(
              'Все данные хранятся только на этом устройстве.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.onInkMuted),
            ),
          ),
        ],
      ),
    );
  }
}

/// Строка настроек как на референсе «Your Settings».
class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.title,
    required this.subtitle,
    this.trailing,
    this.below,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final Widget? trailing;
  final Widget? below;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 16, 16),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: AppColors.inkRaised, width: 1),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: theme.textTheme.titleLarge),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.onInkMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                ?trailing,
              ],
            ),
            if (below != null) ...[
              const SizedBox(height: 12),
              Padding(padding: const EdgeInsets.only(right: 8), child: below),
            ],
          ],
        ),
      ),
    );
  }
}
