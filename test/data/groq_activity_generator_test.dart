import 'dart:convert';

import 'package:chance_affair/data/activity_generator.dart';
import 'package:chance_affair/data/groq_activity_generator.dart';
import 'package:chance_affair/domain/schedule.dart';
import 'package:chance_affair/domain/user_profile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

final _request = ActivityRequest(
  profile: const UserProfile(city: 'Казань', hobbies: ['Музеи']),
  day: ScheduleDay.tomorrow,
  now: DateTime(2026, 10, 8, 9),
  excludeTitles: const ['Кино'],
);

/// Ответ в формате OpenAI chat completions, как отдаёт Groq.
http.Response _groqReply(String content) {
  final body = jsonEncode({
    'choices': [
      {
        'index': 0,
        'message': {'role': 'assistant', 'content': content},
      },
    ],
  });
  return http.Response.bytes(
    utf8.encode(body),
    200,
    headers: {'content-type': 'application/json'},
  );
}

const _activityJson =
    '{"title":"Музей Эрмитаж-Казань","description":"Выставка",'
    '"category":"Культура","emoji":"🏛️","durationMinutes":120,'
    '"preferredStartHour":13}';

GroqActivityGenerator _gen(http.Client client, {Duration? timeout}) =>
    GroqActivityGenerator(
      client: client,
      apiKey: 'gsk_test',
      timeout: timeout ?? const Duration(seconds: 30),
    );

void main() {
  test('отправляет промпт с ключом и разбирает ответ', () async {
    late http.Request sent;
    final client = MockClient((req) async {
      sent = req;
      return _groqReply(_activityJson);
    });

    final activity = await _gen(client).suggest(_request);

    expect(activity.title, 'Музей Эрмитаж-Казань');
    expect(activity.preferredStartHour, 13);
    expect(
      sent.url.toString(),
      'https://api.groq.com/openai/v1/chat/completions',
    );
    expect(sent.headers['Authorization'], 'Bearer gsk_test');

    final payload = jsonDecode(sent.body) as Map<String, dynamic>;
    expect(payload['model'], GroqActivityGenerator.defaultModel);
    final prompt = (payload['messages'] as List).last['content'] as String;
    expect(prompt, contains('Казань'));
    expect(prompt, contains('Музеи'));
    expect(prompt, contains('Кино'));
    final format = payload['response_format'] as Map<String, dynamic>;
    expect(format['type'], 'json_schema');
    expect(format['json_schema']['strict'], isTrue);
  });

  test('понимает JSON, обёрнутый в ```', () async {
    final client = MockClient(
      (_) async => _groqReply('```json\n$_activityJson\n```'),
    );
    final a = await _gen(client).suggest(_request);
    expect(a.category, 'Культура');
  });

  final errors = {
    401: 'Ключ Groq не подходит',
    429: 'Лимит бесплатных запросов',
    500: 'код 500',
  };
  errors.forEach((status, message) {
    test('HTTP $status → понятная ошибка', () async {
      final client = MockClient((_) async => http.Response('{}', status));
      expect(
        _gen(client).suggest(_request),
        throwsA(
          isA<ActivityGenerationException>().having(
            (e) => e.message,
            'message',
            contains(message),
          ),
        ),
      );
    });
  });

  test('мусор в ответе → понятная ошибка', () async {
    final client = MockClient((_) async => _groqReply('не JSON'));
    expect(
      _gen(client).suggest(_request),
      throwsA(isA<ActivityGenerationException>()),
    );
  });

  test('нет сети → понятная ошибка', () async {
    final client = MockClient(
      (_) async => throw http.ClientException('offline'),
    );
    expect(
      _gen(client).suggest(_request),
      throwsA(
        isA<ActivityGenerationException>().having(
          (e) => e.message,
          'message',
          contains('интернет'),
        ),
      ),
    );
  });

  test('таймаут → понятная ошибка', () async {
    final client = MockClient((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 200));
      return _groqReply(_activityJson);
    });
    expect(
      _gen(client, timeout: const Duration(milliseconds: 10)).suggest(_request),
      throwsA(isA<ActivityGenerationException>()),
    );
  });
}
