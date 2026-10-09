import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/feedback_service.dart';
import '../../state/providers.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Форма обратной связи: письмо уходит разработчику на почту.
class FeedbackScreen extends ConsumerStatefulWidget {
  const FeedbackScreen({super.key});

  @override
  ConsumerState<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends ConsumerState<FeedbackScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _message = TextEditingController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _name.text = ref.read(profileProvider).name;
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _message.dispose();
    super.dispose();
  }

  void _toast(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  static String? _validateEmail(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return null;
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v)
        ? null
        : 'Проверьте адрес почты';
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _sending = true);
    try {
      await ref
          .read(feedbackServiceProvider)
          .send(message: _message.text, name: _name.text, email: _email.text);
      if (!mounted) return;
      _toast('Спасибо! Сообщение отправлено');
      Navigator.of(context).pop();
    } on FeedbackException catch (e) {
      if (mounted) _toast(e.message);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.ink,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        top: false,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              const ScreenHeader(
                title: 'Обратная связь',
                subtitle:
                    'Расскажите, что понравилось, что сломалось '
                    'или чего не хватает.',
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    TextFormField(
                      controller: _name,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Имя (необязательно)',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      textInputAction: TextInputAction.next,
                      validator: _validateEmail,
                      decoration: const InputDecoration(
                        labelText: 'Почта для ответа (необязательно)',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _message,
                      minLines: 5,
                      maxLines: 10,
                      maxLength: 2000,
                      textCapitalization: TextCapitalization.sentences,
                      validator: (v) => (v?.trim() ?? '').isEmpty
                          ? 'Напишите сообщение'
                          : null,
                      decoration: const InputDecoration(
                        labelText: 'Сообщение',
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _sending ? null : _send,
                      child: _sending
                          ? const SizedBox.square(
                              dimension: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Отправить'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
