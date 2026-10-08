import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/user_profile.dart';
import '../../state/providers.dart';
import '../theme.dart';
import '../widgets/common.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  static const suggestedHobbies = [
    'Прогулки',
    'Музеи',
    'Спорт',
    'Природа',
    'Кулинария',
    'Фотография',
    'Кино',
    'Настольные игры',
    'Книги',
    'Путешествия',
  ];

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  late final TextEditingController _name;
  late final TextEditingController _city;
  late final TextEditingController _about;
  final _hobbyInput = TextEditingController();
  late List<String> _hobbies;
  late bool _hasCar;
  late Budget _budget;

  @override
  void initState() {
    super.initState();
    final p = ref.read(profileProvider);
    _name = TextEditingController(text: p.name);
    _city = TextEditingController(text: p.city);
    _about = TextEditingController(text: p.about);
    _hobbies = [...p.hobbies];
    _hasCar = p.hasCar;
    _budget = p.budget;
  }

  @override
  void dispose() {
    _name.dispose();
    _city.dispose();
    _about.dispose();
    _hobbyInput.dispose();
    super.dispose();
  }

  void _toggleHobby(String hobby) {
    final h = hobby.trim();
    if (h.isEmpty) return;
    setState(() {
      final existing = _hobbies.indexWhere(
        (x) => x.toLowerCase() == h.toLowerCase(),
      );
      existing >= 0 ? _hobbies.removeAt(existing) : _hobbies.add(h);
    });
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    await ref
        .read(profileProvider.notifier)
        .save(
          UserProfile(
            name: _name.text.trim(),
            city: _city.text.trim(),
            about: _about.text.trim(),
            hobbies: _hobbies,
            hasCar: _hasCar,
            budget: _budget,
          ),
        );
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Профиль сохранён')));
  }

  @override
  Widget build(BuildContext context) {
    final allHobbies = {
      ...ProfileScreen.suggestedHobbies,
      ..._hobbies,
    }.toList();

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          const ScreenHeader(
            title: 'Ваш профиль',
            subtitle:
                'Расскажите о себе — так идеи будут точнее. '
                'Данные хранятся только на телефоне.',
          ),
          _Section(
            children: [
              TextField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Имя'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _city,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Город',
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _about,
                minLines: 3,
                maxLines: 6,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'О себе',
                  hintText:
                      'Например: интроверт, люблю тихие места, '
                      'есть собака, работаю из дома',
                  alignLabelWithHint: true,
                ),
              ),
            ],
          ),
          _Section(
            title: 'Увлечения',
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final h in allHobbies)
                    FilterChip(
                      label: Text(h),
                      selected: _hobbies.contains(h),
                      onSelected: (_) => _toggleHobby(h),
                      selectedColor: AppColors.orange,
                      checkmarkColor: Colors.white,
                      backgroundColor: AppColors.inkRaised,
                      side: BorderSide.none,
                      shape: const StadiumBorder(),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _hobbyInput,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Своё увлечение',
                  suffixIcon: IconButton(
                    tooltip: 'Добавить увлечение',
                    icon: const Icon(Icons.add_circle, color: AppColors.orange),
                    onPressed: () {
                      _toggleHobby(_hobbyInput.text);
                      _hobbyInput.clear();
                    },
                  ),
                ),
                onSubmitted: (v) {
                  _toggleHobby(v);
                  _hobbyInput.clear();
                },
              ),
            ],
          ),
          _Section(
            title: 'Возможности',
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Есть машина'),
                subtitle: const Text(
                  'Можно предлагать поездки за город',
                  style: TextStyle(color: AppColors.onInkMuted),
                ),
                value: _hasCar,
                onChanged: (v) => setState(() => _hasCar = v),
              ),
              const SizedBox(height: 8),
              const Text(
                'Бюджет',
                style: TextStyle(color: AppColors.onInkMuted),
              ),
              const SizedBox(height: 8),
              PillSelector<Budget>(
                values: Budget.values,
                selected: _budget,
                labelOf: (b) => b.label,
                onChanged: (b) => setState(() => _budget = b),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: FilledButton(
              onPressed: _save,
              child: const Text('Сохранить'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({this.title, required this.children});

  final String? title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(title!, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
          ],
          ...children,
        ],
      ),
    );
  }
}
