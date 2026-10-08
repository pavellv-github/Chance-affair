import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../domain/activity.dart';
import 'activity_generator.dart';
import 'prompt_builder.dart';

/// Подбор занятия через бесплатный API Groq (OpenAI-совместимый).
class GroqActivityGenerator implements ActivityGenerator {
  GroqActivityGenerator({
    required this.client,
    required this.apiKey,
    this.model = defaultModel,
    this.timeout = const Duration(seconds: 30),
  });

  /// Открытая модель OpenAI на Groq: быстро и хорошо пишет по-русски.
  static const defaultModel = 'openai/gpt-oss-120b';

  static final endpoint = Uri.https(
    'api.groq.com',
    '/openai/v1/chat/completions',
  );

  final http.Client client;
  final String apiKey;
  final String model;
  final Duration timeout;

  @override
  Future<Activity> suggest(ActivityRequest request) async {
    final body = jsonEncode({
      'model': model,
      'temperature': 1,
      'reasoning_effort': 'low',
      'messages': [
        {
          'role': 'system',
          'content': 'Ты придумываешь, чем заняться. Отвечай только JSON.',
        },
        {'role': 'user', 'content': buildPrompt(request)},
      ],
      'response_format': {
        'type': 'json_schema',
        'json_schema': {
          'name': 'activity',
          'strict': true,
          'schema': activityResponseSchema,
        },
      },
    });

    final http.Response response;
    try {
      response = await client
          .post(
            endpoint,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $apiKey',
            },
            body: body,
          )
          .timeout(timeout);
    } on TimeoutException {
      throw const ActivityGenerationException(
        'ИИ слишком долго думает. Попробуйте ещё раз.',
      );
    } on SocketException {
      throw const ActivityGenerationException('Нет подключения к интернету.');
    } on http.ClientException {
      throw const ActivityGenerationException('Нет подключения к интернету.');
    }

    switch (response.statusCode) {
      case 200:
        // Тело декодируем сами: без charset в заголовке http берёт latin1.
        return _parse(utf8.decode(response.bodyBytes));
      case 401 || 403:
        throw const ActivityGenerationException(
          'Ключ Groq не подходит. Обновите его в настройках.',
        );
      case 429:
        throw const ActivityGenerationException(
          'Лимит бесплатных запросов исчерпан. Попробуйте чуть позже.',
        );
      default:
        throw ActivityGenerationException(
          'Сервис ИИ недоступен (код ${response.statusCode}).',
        );
    }
  }

  Activity _parse(String body) {
    try {
      final json = jsonDecode(body) as Map<String, Object?>;
      final choice = (json['choices'] as List).first as Map;
      final text = (choice['message'] as Map)['content'] as String;
      return Activity.fromJson(
        jsonDecode(_stripFences(text)) as Map<String, Object?>,
      );
    } on Object {
      throw const ActivityGenerationException(
        'ИИ ответил что-то непонятное. Попробуйте ещё раз.',
      );
    }
  }

  /// На случай, если модель всё же обернёт JSON в ```json ... ```.
  static String _stripFences(String text) {
    final t = text.trim();
    if (!t.startsWith('```')) return t;
    final start = t.indexOf('\n');
    final end = t.lastIndexOf('```');
    return start >= 0 && end > start ? t.substring(start + 1, end) : t;
  }
}
