import 'dart:async';
import 'dart:convert';

import 'package:chance_affair/data/feedback_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

http.Response _reply(Object json, [int status = 200]) =>
    http.Response.bytes(utf8.encode(jsonEncode(json)), status);

void main() {
  test('отправляет письмо на почту разработчика с нужной темой', () async {
    late http.Request sent;
    final service = FormSubmitFeedbackService(
      client: MockClient((req) async {
        sent = req;
        return _reply({'success': 'true', 'message': 'ok'});
      }),
    );

    await service.send(
      message: '  Всё супер  ',
      name: 'Павел',
      email: 'me@example.com',
    );

    expect(
      sent.url.toString(),
      'https://formsubmit.co/ajax/pasharus73@gmail.com',
    );
    expect(sent.method, 'POST');
    expect(sent.headers['Origin'], isNotEmpty);
    expect(sent.headers['Referer'], isNotEmpty);
    final body = jsonDecode(sent.body) as Map<String, Object?>;
    expect(body['_subject'], 'Приложение "чем заняться". Форма обратной связи');
    expect(body['Сообщение'], 'Всё супер');
    expect(body['Имя'], 'Павел');
    expect(body['email'], 'me@example.com');
  });

  test('без почты поле email не отправляется', () async {
    late Map<String, Object?> body;
    final service = FormSubmitFeedbackService(
      client: MockClient((req) async {
        body = jsonDecode(req.body) as Map<String, Object?>;
        return _reply({'success': true});
      }),
    );

    await service.send(message: 'Привет');

    expect(body.containsKey('email'), isFalse);
    expect(body['Имя'], 'не указано');
  });

  test(
    'success=false и ошибки HTTP превращаются в FeedbackException',
    () async {
      for (final response in [
        _reply({'success': 'false', 'message': 'needs Activation'}),
        _reply({'success': 'true'}, 500),
        http.Response('<html>', 200),
      ]) {
        final service = FormSubmitFeedbackService(
          client: MockClient((_) async => response),
        );
        expect(service.send(message: 'x'), throwsA(isA<FeedbackException>()));
      }
    },
  );

  test('нет сети и таймаут — понятные сообщения', () async {
    final offline = FormSubmitFeedbackService(
      client: MockClient((_) async => throw http.ClientException('offline')),
    );
    await expectLater(
      offline.send(message: 'x'),
      throwsA(
        isA<FeedbackException>().having(
          (e) => e.message,
          'message',
          'Нет подключения к интернету.',
        ),
      ),
    );

    final slow = FormSubmitFeedbackService(
      client: MockClient((_) => Completer<http.Response>().future),
      timeout: const Duration(milliseconds: 10),
    );
    await expectLater(
      slow.send(message: 'x'),
      throwsA(isA<FeedbackException>()),
    );
  });
}
