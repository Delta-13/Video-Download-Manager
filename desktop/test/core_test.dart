import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:vdm/core/engines.dart';
import 'package:vdm/core/models.dart';
import 'package:vdm/core/store.dart';
import 'package:vdm/ui/design.dart';
import 'package:flutter/material.dart';

double contrast(Color a, Color b) {
  final values = [a.computeLuminance(), b.computeLuminance()]..sort();
  return (values.last + .05) / (values.first + .05);
}

void main() {
  test('accept supported URLs and reject unsafe inputs', () {
    for (final url in [
      'https://www.youtube.com/watch?v=abc',
      'https://x.com/name/status/123',
      'https://www.instagram.com/reel/abc/',
      'https://www.pornhub.com/view_video.php?viewkey=abc',
    ]) {
      expect(validateSource(url), url);
    }
    for (final url in [
      'file:///secret',
      'javascript:alert(1)',
      'https://',
      'https://user:pass@example.com/a',
      'https://example.com/a\n--exec',
      'magnet:?xt=abc',
    ]) {
      expect(() => validateSource(url), throwsFormatException);
    }
    expect(detectKind('https://example.com/file.zip?token=abc'), TaskKind.file);
    expect(detectKind('magnet:?xt=urn:btih:${'a' * 40}'), TaskKind.torrent);
  });
  test('sanitize Windows filenames', () {
    expect(safeName('CON.txt'), '_CON.txt');
    expect(safeName('../a:b?. '), '.._a_b_');
    expect(safeName(''), 'download');
    expect(safeName('a' * 300).length, lessThanOrEqualTo(160));
  });
  test(
    'YouTube storyboards and audio do not become selectable video qualities',
    () {
      final info = VideoInfo({
        'formats': <Map<String, dynamic>>[
          {
            'format_id': 'sb3',
            'height': 27,
            'vcodec': 'none',
            'protocol': 'mhtml',
          },
          {'format_id': 'sb0', 'height': 180, 'protocol': 'mhtml'},
          {'format_id': '140', 'vcodec': 'none', 'acodec': 'mp4a.40.2'},
          {'format_id': '134', 'height': 360, 'vcodec': 'avc1.4d401e'},
          {'format_id': '396', 'height': 360, 'vcodec': 'av01.0.01M.08'},
          {'format_id': '399', 'height': 1080, 'vcodec': 'av01.0.09M.08'},
        ],
      });
      expect(info.videoHeights, [1080, 360]);
      expect(info.videoFormats.map((format) => format['format_id']), [
        '134',
        '396',
        '399',
      ]);
    },
  );
  test(
    'SQLite round trip preserves resumable tasks and protected settings',
    () {
      final store = TaskStore(':memory:');
      final task = DownloadTask(
        id: 'id',
        source: 'https://example.com/video',
        kind: TaskKind.video,
        title: '视频',
        options: DownloadOptions(
          directory: r'C:\Downloads',
          subtitle: 'zh-Hans',
        ),
        progress: DownloadProgress(received: 100, total: 200),
        status: TaskStatus.paused,
        schedule: Schedule(
          DateTime(2026, 10, 1, 12),
          repeat: RepeatRule.weekly,
        ),
      );
      store.save(task);
      final loaded = store.load().single;
      expect(jsonEncode(loaded.toJson()), jsonEncode(task.toJson()));
      store.set('cookies', {'example.com': 'encrypted'});
      expect(store.setting('cookies', {})['example.com'], 'encrypted');
      store.remove('id');
      expect(store.load(), isEmpty);
      store.close();
    },
  );
  test(
    'calendar schedules keep local hour across month and year boundaries',
    () {
      final daily = Schedule(
        DateTime(2026, 12, 31, 19, 30),
        repeat: RepeatRule.daily,
      );
      expect(daily.following(daily.next), DateTime(2027, 1, 1, 19, 30));
      final weekly = Schedule(
        DateTime(2026, 12, 28, 8),
        repeat: RepeatRule.weekly,
      );
      expect(weekly.following(weekly.next), DateTime(2027, 1, 4, 8));
    },
  );
  test(
    'yt-dlp commands preserve URL as one argument, route protocols, and wait for after_move',
    () {
      final task = DownloadTask(
        id: 'id',
        source: 'https://example.com/a?x=1&y=2',
        kind: TaskKind.video,
        title: '视频',
        options: DownloadOptions(directory: r'C:\My Downloads', height: 1080),
      );
      final args = videoArguments(
        task,
        EnginePaths(r'C:\VDM\engines'),
        r'C:\My Downloads\.vdm\id',
        null,
      );
      expect(args.last, task.source);
      expect(args[args.length - 2], '--');
      expect(args, contains('dash,m3u8:native'));
      expect(args, contains('after_move:VDM_FILE:%(filepath)j'));
      expect(args, contains('--no-overwrites'));
      expect(args, contains('--abort-on-unavailable-fragments'));
    },
  );
  test(
    'unknown progress remains unknown; external aria output parsed without fabricating bytes',
    () {
      expect(DownloadProgress().fraction, isNull);
      expect(parseAriaProgress('not progress'), isNull);
      final progress = parseAriaProgress(
        '[#abc123 4096B/8192B(50%) CN:4 DL:1024B ETA:4s]',
      )!;
      expect(progress.fraction, .5);
      expect(progress.connections, 4);
      expect(progress.speed, 1024);
    },
  );
  test('errors do not expose private URLs or credentials', () {
    final text = classifyError(
      'ERROR https://example.com/private?token=secret HTTP 403 Cookie secret',
    );
    expect(text, isNot(contains('secret')));
    expect(text, contains('cookies.txt'));
  });
  for (final dark in [false, true]) {
    test(
      '${dark ? 'dark' : 'light'} theme meets contrast on glass extremes and interaction surfaces',
      () {
        final c = Palette(dark);
        final backgrounds = [
          c.surface,
          Color.alphaBlend(c.surface.withValues(alpha: .94), Colors.black),
          Color.alphaBlend(c.surface.withValues(alpha: .94), Colors.white),
          Color.alphaBlend(c.accent.withValues(alpha: .1), c.surface),
        ];
        for (final bg in backgrounds) {
          expect(contrast(c.text, bg), greaterThanOrEqualTo(4.5));
          expect(contrast(c.secondary, bg), greaterThanOrEqualTo(4.5));
          expect(contrast(c.accent, bg), greaterThanOrEqualTo(4.5));
          expect(contrast(c.border, bg), greaterThanOrEqualTo(3));
        }
        expect(contrast(c.onAccent, c.accent), greaterThanOrEqualTo(4.5));
      },
    );
  }
}
