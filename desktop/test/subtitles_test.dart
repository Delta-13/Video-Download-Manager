import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:vdm/subtitles/document.dart';
import 'package:vdm/subtitles/translator.dart';

const sample =
    '7\n00:00:01,025 --> 00:00:03,500\nHello &amp; welcome.\nSecond line.\n\n9\n00:00:03,500 --> 00:00:05,900\nGoodbye.\n';
void main() {
  test('SRT roundtrip preserves exact timing and multiline text', () {
    final doc = SubtitleDocument.parse(
      'sample.srt',
      '\uFEFF${sample.replaceAll('\n', '\r\n')}',
    );
    expect(doc.cues.length, 2);
    expect(doc.cues.first.start, 1025);
    expect(doc.cues.last.end, 5900);
    expect(doc.cues.first.text, 'Hello & welcome.\nSecond line.');
    doc.cues[0].translation = '你好，欢迎。\n第二行。';
    doc.cues[1].translation = '再见。';
    final reloaded = SubtitleDocument.parse(
      'bilingual.vtt',
      doc.render(bilingual: true, format: 'vtt'),
    );
    expect(
      reloaded.cues.first.text,
      'Hello & welcome.\nSecond line.\n你好，欢迎。\n第二行。',
    );
    expect(reloaded.cues.last.end, 5900);
    expect(SubtitleDocument.fromJson(doc.toJson()).translated, 2);
  });
  test('WebVTT supports identifiers, settings, tags and metadata', () {
    final doc = SubtitleDocument.parse(
      'sample.vtt',
      'WEBVTT\n\nNOTE ignored\nmetadata\n\nSTYLE\n::cue {color: red}\n\nintro\n00:01.000 --> 00:02.500 align:start\n<v Alice><b>Hello</b></v>\n',
    );
    expect(doc.cues.single.text, 'Hello');
    expect(doc.cues.single.start, 1000);
  });
  test(
    'invalid timing and empty inputs fail, incomplete translation cannot export',
    () {
      expect(
        () => SubtitleDocument.parse('x.srt', 'no subtitles'),
        throwsFormatException,
      );
      expect(
        () => SubtitleDocument.parse(
          'x.srt',
          '1\n00:00:02,000 --> 00:00:01,000\nx',
        ),
        throwsFormatException,
      );
      expect(() => parseTime('00:61:00.000'), throwsFormatException);
      final doc = SubtitleDocument.parse('x.srt', sample);
      expect(() => doc.render(bilingual: false), throwsStateError);
      expect(
        doc.render(bilingual: false, original: true),
        contains('00:00:01,025'),
      );
    },
  );
  test(
    'model output aligns by ID and rejects omissions, duplicates and fabricated IDs',
    () {
      expect(
        validatedTranslations(
          '```json\n{"translations":[{"id":2,"text":"乙"},{"id":0,"text":"甲"}]}\n```',
          {0, 2},
        ),
        {2: '乙', 0: '甲'},
      );
      for (final items in [
        [],
        [
          {'id': 0, 'text': '甲'},
        ],
        [
          {'id': 0, 'text': '甲'},
          {'id': 0, 'text': '甲'},
        ],
        [
          {'id': 0, 'text': '甲'},
          {'id': 3, 'text': '乙'},
        ],
        [
          {'id': 0, 'text': ''},
          {'id': 2, 'text': '乙'},
        ],
      ]) {
        expect(
          () => validatedTranslations(jsonEncode({'translations': items}), {
            0,
            2,
          }),
          throwsFormatException,
        );
      }
    },
  );
  test(
    'local mode rejects remote endpoints/cloud models and online requires TLS',
    () {
      for (final config in [
        const TranslationConfig(endpoint: 'https://example.com'),
        const TranslationConfig(model: 'model:cloud'),
        const TranslationConfig(
          local: false,
          endpoint: 'http://example.com/v1',
        ),
        const TranslationConfig(endpoint: 'http://user:secret@localhost:11434'),
        const TranslationConfig(endpoint: 'http://localhost:11434?key=secret'),
      ]) {
        expect(() => config.uri('api/chat'), throwsA(isA<SubtitleFailure>()));
      }
      expect(
        const TranslationConfig(
          local: false,
          endpoint: 'https://example.com/v1/',
        ).uri('chat/completions').path,
        '/v1/chat/completions',
      );
    },
  );

  late HttpServer server;
  late String endpoint;
  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    endpoint = 'http://127.0.0.1:${server.port}';
  });
  tearDown(() async {
    await server.close(force: true);
  });
  Future<void> respond(
    HttpRequest request,
    dynamic data, {
    int code = 200,
  }) async {
    request.response.statusCode = code;
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode(data));
    await request.response.close();
  }

  test(
    'online protocol authenticates, retries HTTP 503, validates order and checkpoints',
    () async {
      var requests = 0, saved = 0;
      server.listen((r) async {
        expect(r.uri.path, '/v1/chat/completions');
        expect(r.headers.value('authorization'), 'Bearer test-only-key');
        final body = jsonDecode(await utf8.decoder.bind(r).join());
        expect(body['stream'], false);
        expect(body['response_format']['type'], 'json_object');
        requests++;
        if (requests == 1) {
          await respond(r, {'error': 'fixture'}, code: 503);
          return;
        }
        final entries =
            jsonDecode(body['messages'][1]['content'])['subtitles'] as List;
        await respond(r, {
          'choices': [
            {
              'message': {
                'content': jsonEncode({
                  'translations': entries.reversed
                      .map((e) => {'id': e['id'], 'text': '译文 ${e['id']}'})
                      .toList(),
                }),
              },
            },
          ],
        });
      });
      final doc = SubtitleDocument.parse('fixture.srt', sample);
      await SubtitleTranslator().translate(
        doc,
        TranslationConfig(
          local: false,
          endpoint: '$endpoint/v1',
          model: 'fixture',
        ),
        apiKey: 'test-only-key',
        onProgress: (_) {},
        checkpoint: () {
          saved++;
        },
      );
      expect(doc.cues.map((c) => c.translation), ['译文 0', '译文 1']);
      expect(requests, 2);
      expect(saved, 2);
    },
  );
  test(
    'cancel saves first batch and resume does not retransmit completed cues',
    () async {
      final requested = <int>[];
      server.listen((r) async {
        expect(r.headers.value('authorization'), isNull);
        final body = jsonDecode(await utf8.decoder.bind(r).join());
        final entries =
            jsonDecode(body['messages'][1]['content'])['subtitles'] as List;
        requested.addAll(entries.map((e) => e['id'] as int));
        await respond(r, {
          'message': {
            'content': jsonEncode({
              'translations': entries
                  .map((e) => {'id': e['id'], 'text': '译文 ${e['id']}'})
                  .toList(),
            }),
          },
        });
      });
      final doc = SubtitleDocument.parse('fixture.srt', sample);
      final config = TranslationConfig(
        endpoint: endpoint,
        model: 'fixture',
        batchSize: 1,
      );
      final first = SubtitleTranslator();
      await expectLater(
        first.translate(
          doc,
          config,
          onProgress: (_) {},
          checkpoint: () {
            if (doc.translated == 1) first.cancel();
          },
        ),
        throwsA(isA<SubtitleCanceled>()),
      );
      expect(doc.translated, 1);
      final restored = SubtitleDocument.fromJson(
        jsonDecode(jsonEncode(doc.toJson())),
      );
      await SubtitleTranslator().translate(
        restored,
        config,
        onProgress: (_) {},
        checkpoint: () {},
      );
      expect(restored.translated, 2);
      expect(requested, [0, 1]);
    },
  );
  test('malformed batches never partially commit', () async {
    var attempts = 0;
    server.listen((r) async {
      await r.drain<void>();
      attempts++;
      await respond(r, {
        'message': {'content': '{"translations":[{"id":0,"text":"partial"}]}'},
      });
    });
    final doc = SubtitleDocument.parse('fixture.srt', sample);
    await expectLater(
      SubtitleTranslator().translate(
        doc,
        TranslationConfig(endpoint: endpoint, model: 'fixture'),
        onProgress: (_) {},
        checkpoint: () {},
      ),
      throwsFormatException,
    );
    expect(attempts, 3);
    expect(doc.translated, 0);
  });
  test('HTTP errors do not expose credentials or upstream body', () async {
    server.listen(
      (r) => respond(r, {'error': 'sensitive-key-and-subtitle'}, code: 401),
    );
    try {
      await SubtitleTranslator().translate(
        SubtitleDocument.parse('fixture.srt', sample),
        TranslationConfig(endpoint: endpoint, model: 'fixture'),
        onProgress: (_) {},
        checkpoint: () {},
      );
      fail('Expected authentication failure');
    } on SubtitleFailure catch (error) {
      expect(error.message, contains('认证'));
      expect(error.message, isNot(contains('sensitive')));
    }
  });
  test('redirects are not followed', () async {
    var count = 0;
    server.listen((r) async {
      count++;
      r.response.headers.set('location', '$endpoint/redirect');
      await respond(r, {}, code: 302);
    });
    await expectLater(
      SubtitleTranslator().translate(
        SubtitleDocument.parse('x', sample),
        TranslationConfig(endpoint: endpoint, model: 'fixture'),
        onProgress: (_) {},
        checkpoint: () {},
      ),
      throwsA(isA<SubtitleFailure>()),
    );
    expect(count, 1);
  });
  test('cancel aborts an in-flight request promptly', () async {
    final received = Completer<void>();
    server.listen((r) async {
      await r.drain<void>();
      received.complete();
    });
    final translator = SubtitleTranslator();
    final pending = translator.translate(
      SubtitleDocument.parse('x', sample),
      TranslationConfig(endpoint: endpoint, model: 'fixture'),
      onProgress: (_) {},
      checkpoint: () {},
    );
    final assertion = expectLater(pending, throwsA(isA<SubtitleCanceled>()));
    await received.future;
    translator.cancel();
    await assertion.timeout(const Duration(seconds: 3));
  });
  test('Ollama model list filters cloud descriptors', () async {
    server.listen(
      (r) => respond(r, {
        'models': [
          {'name': 'local:3b'},
          {'name': 'large:cloud'},
          {'name': 'alias', 'remote_model': 'cloud-model'},
        ],
      }),
    );
    expect(
      await SubtitleTranslator().localModels(
        TranslationConfig(endpoint: endpoint),
      ),
      ['local:3b'],
    );
  });
}
