import 'dart:convert';

class SubtitleCue {
  final int start, end;
  final String text;
  String? translation;
  SubtitleCue(this.start, this.end, this.text, {this.translation});
  Map<String, dynamic> toJson() => {
    'start': start,
    'end': end,
    'text': text,
    'translation': translation,
  };
  factory SubtitleCue.fromJson(Map<String, dynamic> j) => SubtitleCue(
    j['start'],
    j['end'],
    j['text'],
    translation: j['translation'],
  );
}

class SubtitleDocument {
  final String source;
  final List<SubtitleCue> cues;
  String? translationKey;
  SubtitleDocument(this.source, this.cues, {this.translationKey});
  int get translated => cues.where((c) => c.translation != null).length;
  Map<String, dynamic> toJson() => {
    'source': source,
    'cues': cues.map((c) => c.toJson()).toList(),
    'translationKey': translationKey,
  };
  factory SubtitleDocument.fromJson(Map<String, dynamic> j) => SubtitleDocument(
    j['source'],
    (j['cues'] as List).map((c) => SubtitleCue.fromJson(c)).toList(),
    translationKey: j['translationKey'],
  );

  // Parse timing blocks rather than relying on sequential SRT cue numbers.
  // VTT cue identifiers/settings are allowed; styling is deliberately flattened.
  static SubtitleDocument parse(String source, String content) {
    final normalized = content
        .replaceAll('\uFEFF', '')
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n');
    final timing = RegExp(
      r'^(\d{1,}:\d{2}:\d{2}[.,]\d{3}|\d{2}:\d{2}[.,]\d{3})\s+-->\s+(\d{1,}:\d{2}:\d{2}[.,]\d{3}|\d{2}:\d{2}[.,]\d{3})(?:\s+.*)?$',
    );
    final cues = <SubtitleCue>[];
    for (final block in normalized.split(RegExp(r'\n[ \t]*\n'))) {
      final lines = block.trim().split('\n');
      if (lines.isEmpty ||
          RegExp(r'^(NOTE(?:\s|$)|STYLE$|REGION$)').hasMatch(lines.first)) {
        continue;
      }
      final index = lines.indexWhere((l) => timing.hasMatch(l.trim()));
      if (index < 0) {
        if (block.contains('-->')) throw const FormatException('字幕时间码格式无效。');
        continue;
      }
      final match = timing.firstMatch(lines[index].trim())!;
      final start = parseTime(match[1]!), end = parseTime(match[2]!);
      if (end <= start) throw const FormatException('字幕结束时间必须晚于开始时间。');
      var text = lines.skip(index + 1).join('\n').trim();
      text = text
          .replaceAll(RegExp(r'<[^>]*>'), '')
          .replaceAll('&lt;', '<')
          .replaceAll('&gt;', '>')
          .replaceAll('&nbsp;', ' ')
          .replaceAll('&amp;', '&');
      if (text.isNotEmpty) cues.add(SubtitleCue(start, end, text));
    }
    if (cues.isEmpty) {
      throw const FormatException('未找到有效字幕。请导入 UTF-8 编码的 SRT、VTT 或 ASS 文件。');
    }
    return SubtitleDocument(source, cues);
  }

  String render({
    required bool bilingual,
    bool original = false,
    String format = 'srt',
  }) {
    if (!original && translated != cues.length) {
      throw StateError('请先完成全部字幕的翻译。');
    }
    final vtt = format == 'vtt';
    final output = StringBuffer(vtt ? 'WEBVTT\n\n' : '');
    for (var i = 0; i < cues.length; i++) {
      final c = cues[i];
      final lines = original
          ? c.text
          : bilingual
          ? '${c.text}\n${c.translation!}'
          : c.translation!;
      output.writeln(
        '${i + 1}\n${timestamp(c.start, vtt: vtt)} --> ${timestamp(c.end, vtt: vtt)}',
      );
      // Escape cue markup and prevent model-produced blank lines splitting cues.
      output.writeln(
        lines
            .replaceAll('&', '&amp;')
            .replaceAll('<', '&lt;')
            .replaceAll('>', '&gt;')
            .replaceAll(RegExp(r'\n\s*\n'), '\n'),
      );
      output.writeln();
    }
    return output.toString();
  }
}

int parseTime(String value) {
  final parts = value.replaceAll(',', '.').split(':');
  final seconds = double.parse(parts.removeLast());
  final minutes = int.parse(parts.removeLast());
  final hours = parts.isEmpty ? 0 : int.parse(parts.single);
  if (seconds >= 60 || minutes >= 60) throw const FormatException('字幕时间码无效。');
  return hours * 3600000 + minutes * 60000 + (seconds * 1000).round();
}

String timestamp(int ms, {bool vtt = false}) =>
    '${(ms ~/ 3600000).toString().padLeft(2, '0')}:${(ms ~/ 60000 % 60).toString().padLeft(2, '0')}:${(ms ~/ 1000 % 60).toString().padLeft(2, '0')}${vtt ? '.' : ','}${(ms % 1000).toString().padLeft(3, '0')}';

/// A provider must return every requested ID exactly once. Never align by order.
Map<int, String> validatedTranslations(String response, Set<int> expected) {
  var text = response.trim();
  if (text.startsWith('```')) {
    text = text
        .replaceFirst(RegExp(r'^```(?:json)?\s*'), '')
        .replaceFirst(RegExp(r'\s*```$'), '');
  }
  final data = jsonDecode(text);
  if (data is! Map || data['translations'] is! List) {
    throw const FormatException('翻译响应缺少 translations 数组。');
  }
  final result = <int, String>{};
  for (final item in data['translations']) {
    if (item is! Map || item['id'] is! int || item['text'] is! String) {
      throw const FormatException('翻译响应格式不正确。');
    }
    final id = item['id'] as int, value = (item['text'] as String).trim();
    if (!expected.contains(id) ||
        result.containsKey(id) ||
        value.isEmpty ||
        value.length > 20000 ||
        value.contains('-->')) {
      throw const FormatException('翻译响应的字幕编号或内容不完整。');
    }
    result[id] = value
        .replaceAll('\r', '')
        .replaceAll(RegExp(r'\n\s*\n'), '\n');
  }
  if (result.length != expected.length) {
    throw const FormatException('翻译响应漏掉了字幕；本批次未保存。');
  }
  return result;
}
