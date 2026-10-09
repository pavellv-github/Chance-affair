import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// Отправка сообщений обратной связи разработчику.
abstract interface class FeedbackService {
  Future<void> send({
    required String message,
    String name = '',
    String email = '',
  });
}

/// Ошибка отправки с понятным пользователю текстом.
class FeedbackException implements Exception {
  const FeedbackException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Отправляет письмо через бесплатный сервис FormSubmit (formsubmit.co):
/// своего сервера у приложения нет, а FormSubmit пересылает POST-запрос
/// на почту без ключей. Первое письмо придёт с просьбой подтвердить адрес.
class FormSubmitFeedbackService implements FeedbackService {
  FormSubmitFeedbackService({
    required this.client,
    this.recipient = defaultRecipient,
    this.timeout = const Duration(seconds: 20),
  });

  static const defaultRecipient = 'pasharus73@gmail.com';
  static const subject = 'Приложение "чем заняться". Форма обратной связи';
  static const origin = 'https://chance-affair.app';

  final http.Client client;
  final String recipient;
  final Duration timeout;

  Uri get endpoint => Uri.https('formsubmit.co', '/ajax/$recipient');

  @override
  Future<void> send({
    required String message,
    String name = '',
    String email = '',
  }) async {
    final body = jsonEncode({
      '_subject': subject,
      '_template': 'table',
      '_captcha': 'false',
      'Имя': name.trim().isEmpty ? 'не указано' : name.trim(),
      // FormSubmit подставляет поле email в Reply-To — удобно ответить.
      if (email.trim().isNotEmpty) 'email': email.trim(),
      'Сообщение': message.trim(),
    });

    final http.Response response;
    try {
      response = await client
          .post(
            endpoint,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              // Без Origin/Referer FormSubmit отвечает «откройте страницу
              // через веб-сервер», а мобильный http-клиент их не ставит.
              'Origin': origin,
              'Referer': '$origin/',
            },
            body: body,
          )
          .timeout(timeout);
    } on TimeoutException {
      throw const FeedbackException(
        'Сервер долго не отвечает. Попробуйте ещё раз.',
      );
    } on SocketException {
      throw const FeedbackException('Нет подключения к интернету.');
    } on http.ClientException {
      throw const FeedbackException('Нет подключения к интернету.');
    }

    if (response.statusCode != 200 || !_isSuccess(response)) {
      throw const FeedbackException(
        'Не удалось отправить сообщение. Попробуйте позже.',
      );
    }
  }

  /// FormSubmit отвечает {"success": "true"} или {"success": "false", ...}.
  static bool _isSuccess(http.Response response) {
    try {
      final json = jsonDecode(utf8.decode(response.bodyBytes)) as Map;
      return '${json['success']}' == 'true';
    } on Object {
      return false;
    }
  }
}
