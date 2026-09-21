import 'dart:convert';
import 'package:path/path.dart' as p;

enum TaskKind { video, file, torrent }

enum TaskStatus {
  queued,
  resolving,
  downloading,
  merging,
  converting,
  awaitingSelection,
  paused,
  scheduled,
  completed,
  seeding,
  failed,
  canceled,
}

extension TaskStatusLabel on TaskStatus {
  String get label => const {
    TaskStatus.queued: '排队中',
    TaskStatus.resolving: '正在解析',
    TaskStatus.downloading: '下载中',
    TaskStatus.merging: '正在合并',
    TaskStatus.converting: '正在转换',
    TaskStatus.awaitingSelection: '选择文件',
    TaskStatus.paused: '已暂停',
    TaskStatus.scheduled: '等待计划',
    TaskStatus.completed: '已完成',
    TaskStatus.seeding: '做种中',
    TaskStatus.failed: '下载失败',
    TaskStatus.canceled: '已取消',
  }[this]!;
  bool get active => {
    TaskStatus.resolving,
    TaskStatus.downloading,
    TaskStatus.merging,
    TaskStatus.converting,
  }.contains(this);
}

class DownloadOptions {
  String directory;
  int? height;
  String? formatId, audioLanguage, subtitle, referer;
  bool audioOnly, automaticSubtitle;
  String subtitleFormat;
  int connections, fragments, speedLimit, seedMinutes;
  double seedRatio;
  DownloadOptions({
    required this.directory,
    this.height,
    this.formatId,
    this.audioLanguage,
    this.audioOnly = false,
    this.subtitle,
    this.automaticSubtitle = false,
    this.subtitleFormat = 'srt',
    this.connections = 8,
    this.fragments = 4,
    this.speedLimit = 0,
    this.seedRatio = 1,
    this.seedMinutes = 0,
    this.referer,
  });
  Map<String, dynamic> toJson() => {
    'directory': directory,
    'height': height,
    'formatId': formatId,
    'audioLanguage': audioLanguage,
    'audioOnly': audioOnly,
    'subtitle': subtitle,
    'automaticSubtitle': automaticSubtitle,
    'subtitleFormat': subtitleFormat,
    'connections': connections,
    'fragments': fragments,
    'speedLimit': speedLimit,
    'seedRatio': seedRatio,
    'seedMinutes': seedMinutes,
    'referer': referer,
  };
  factory DownloadOptions.fromJson(Map<String, dynamic> j) => DownloadOptions(
    directory: j['directory'],
    height: j['height'],
    formatId: j['formatId'],
    audioLanguage: j['audioLanguage'],
    audioOnly: j['audioOnly'] ?? false,
    subtitle: j['subtitle'],
    automaticSubtitle: j['automaticSubtitle'] ?? false,
    subtitleFormat: j['subtitleFormat'] ?? 'srt',
    connections: j['connections'] ?? 8,
    fragments: j['fragments'] ?? 4,
    speedLimit: j['speedLimit'] ?? 0,
    seedRatio: (j['seedRatio'] ?? 1).toDouble(),
    seedMinutes: j['seedMinutes'] ?? 0,
    referer: j['referer'],
  );
  DownloadOptions clone() => DownloadOptions.fromJson(toJson());
  String get contentKey => jsonEncode({
    'directory': directory,
    'height': height,
    'formatId': formatId,
    'audioLanguage': audioLanguage,
    'audioOnly': audioOnly,
    'subtitle': subtitle,
    'automaticSubtitle': automaticSubtitle,
    'subtitleFormat': subtitleFormat,
  });
}

class DownloadProgress {
  int received, total, upload, connections;
  double speed, uploadSpeed, ratio;
  int? eta;
  DownloadProgress({
    this.received = 0,
    this.total = 0,
    this.speed = 0,
    this.upload = 0,
    this.uploadSpeed = 0,
    this.connections = 0,
    this.ratio = 0,
    this.eta,
  });
  double? get fraction => total > 0 ? (received / total).clamp(0, 1) : null;
  Map<String, dynamic> toJson() => {'received': received, 'total': total};
  factory DownloadProgress.fromJson(Map<String, dynamic> j) =>
      DownloadProgress(received: j['received'] ?? 0, total: j['total'] ?? 0);
}

enum RepeatRule { once, daily, weekly }

class Schedule {
  DateTime next;
  RepeatRule repeat;
  bool missed;
  Schedule(this.next, {this.repeat = RepeatRule.once, this.missed = false});
  DateTime following(DateTime from) => DateTime(
    from.year,
    from.month,
    from.day + (repeat == RepeatRule.weekly ? 7 : 1),
    next.hour,
    next.minute,
  );
  Map<String, dynamic> toJson() => {
    'next': next.toIso8601String(),
    'repeat': repeat.name,
    'missed': missed,
  };
  factory Schedule.fromJson(Map<String, dynamic> j) => Schedule(
    DateTime.parse(j['next']),
    repeat: RepeatRule.values.byName(j['repeat']),
    missed: j['missed'] ?? false,
  );
}

class TorrentFile {
  final int index;
  final String path;
  final int size;
  final bool selected;
  TorrentFile(this.index, this.path, this.size, this.selected);
}

class DownloadTask {
  final String id, source;
  final TaskKind kind;
  String title, identity;
  TaskStatus status;
  DownloadOptions options;
  DownloadProgress progress;
  DateTime created;
  String? gid, error, output, requestId;
  Schedule? schedule;
  List<TorrentFile> files = [];
  List<int> selectedFiles;
  List<String> subtitleOutputs;
  bool filesConfirmed, published;
  DownloadTask({
    required this.id,
    required this.source,
    required this.kind,
    required this.title,
    required this.options,
    this.identity = '',
    this.status = TaskStatus.queued,
    DownloadProgress? progress,
    DateTime? created,
    this.gid,
    this.error,
    this.output,
    this.schedule,
    this.selectedFiles = const [],
    this.subtitleOutputs = const [],
    this.filesConfirmed = false,
    this.published = false,
    this.requestId,
  }) : progress = progress ?? DownloadProgress(),
       created = created ?? DateTime.now();
  bool get canPause =>
      status == TaskStatus.downloading ||
      status == TaskStatus.resolving ||
      status == TaskStatus.seeding;
  bool get canResume => {
    TaskStatus.paused,
    TaskStatus.failed,
    TaskStatus.canceled,
  }.contains(status);
  String get host => Uri.tryParse(source)?.host ?? '';
  Map<String, dynamic> toJson() => {
    'id': id,
    'source': source,
    'kind': kind.name,
    'title': title,
    'identity': identity,
    'status': status.name,
    'options': options.toJson(),
    'progress': progress.toJson(),
    'created': created.toIso8601String(),
    'gid': gid,
    'error': error,
    'output': output,
    'schedule': schedule?.toJson(),
    'selectedFiles': selectedFiles,
    'subtitleOutputs': subtitleOutputs,
    'filesConfirmed': filesConfirmed,
    'published': published,
    'requestId': requestId,
  };
  factory DownloadTask.fromJson(Map<String, dynamic> j) => DownloadTask(
    id: j['id'],
    source: j['source'],
    kind: TaskKind.values.byName(j['kind']),
    title: j['title'],
    identity: j['identity'] ?? '',
    status: TaskStatus.values.byName(j['status']),
    options: DownloadOptions.fromJson(j['options']),
    progress: DownloadProgress.fromJson(j['progress'] ?? {}),
    created: DateTime.parse(j['created']),
    gid: j['gid'],
    error: j['error'],
    output: j['output'],
    schedule: j['schedule'] == null ? null : Schedule.fromJson(j['schedule']),
    selectedFiles: List<int>.from(j['selectedFiles'] ?? []),
    subtitleOutputs: List<String>.from(j['subtitleOutputs'] ?? []),
    filesConfirmed: j['filesConfirmed'] ?? false,
    published: j['published'] ?? false,
    requestId: j['requestId'],
  );
}

class VideoInfo {
  final Map<String, dynamic> raw;
  VideoInfo(this.raw);
  String get title => raw['title'] ?? raw['id'] ?? '视频';
  String get url =>
      raw['webpage_url'] ?? raw['original_url'] ?? raw['url'] ?? '';
  String get identity =>
      '${raw['extractor_key'] ?? raw['extractor'] ?? Uri.tryParse(url)?.host}:${raw['id'] ?? url}';
  bool get collection => raw['entries'] is List;
  List<VideoInfo> get entries => (raw['entries'] as List? ?? [])
      .whereType<Map<String, dynamic>>()
      .map(VideoInfo.new)
      .toList();
  List<Map<String, dynamic>> get formats => (raw['formats'] as List? ?? [])
      .whereType<Map<String, dynamic>>()
      .toList();
  // yt-dlp includes YouTube storyboard images in its formats array.
  List<Map<String, dynamic>> get videoFormats => formats
      .where(
        (format) => format['vcodec'] != 'none' && format['protocol'] != 'mhtml',
      )
      .toList();
  List<int> get videoHeights =>
      (videoFormats
          .map((format) => format['height'])
          .whereType<num>()
          .map((height) => height.toInt())
          .where((height) => height > 0)
          .toSet()
          .toList()
        ..sort((a, b) => b.compareTo(a)));
  Map<String, dynamic> get subtitles =>
      Map<String, dynamic>.from(raw['subtitles'] ?? {});
  Map<String, dynamic> get automaticCaptions =>
      Map<String, dynamic>.from(raw['automatic_captions'] ?? {});
}

String validateSource(String input, {bool allowTorrentFile = false}) {
  final value = input.trim();
  if (allowTorrentFile &&
      p.extension(value).toLowerCase() == '.torrent' &&
      p.isAbsolute(value)) {
    return value;
  }
  final uri = Uri.tryParse(value);
  if (uri == null || value.contains(RegExp(r'[\x00-\x20]'))) {
    throw const FormatException('请输入完整链接');
  }
  if (uri.scheme == 'magnet' &&
      uri.queryParametersAll['xt']?.any(
            (v) => RegExp(
              r'^urn:btih:([a-fA-F0-9]{40}|[A-Z2-7a-z]{32})$',
            ).hasMatch(v),
          ) ==
          true) {
    return value;
  }
  if (!{'http', 'https'}.contains(uri.scheme) ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty) {
    throw const FormatException('支持 HTTP/HTTPS 网页、文件链接和有效磁力链接');
  }
  return value;
}

TaskKind detectKind(String source) {
  if (source.startsWith('magnet:') ||
      (Uri.tryParse(source)?.path ?? source).toLowerCase().endsWith(
        '.torrent',
      )) {
    return TaskKind.torrent;
  }
  final ext = p.extension(Uri.parse(source).path).toLowerCase();
  return {
        '.zip',
        '.7z',
        '.rar',
        '.exe',
        '.msi',
        '.iso',
        '.pdf',
        '.mp4',
        '.mkv',
        '.mp3',
        '.wav',
        '.bin',
        '.tar',
        '.gz',
      }.contains(ext)
      ? TaskKind.file
      : TaskKind.video;
}

String safeName(String name) {
  var clean = name
      .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1f]'), '_')
      .replaceAll(RegExp(r'[. ]+$'), '');
  if (clean.isEmpty) {
    clean = 'download';
  }
  if (RegExp(
    r'^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(?:\.|$)',
    caseSensitive: false,
  ).hasMatch(clean)) {
    clean = '_$clean';
  }
  if (clean.length > 160) {
    final ext = p.extension(clean);
    clean =
        '${clean.substring(0, 140)}${ext.substring(0, ext.length.clamp(0, 16))}';
  }
  return clean;
}

String classifyError(String message) {
  final lower = message.toLowerCase();
  if ([
    'cookie',
    'sign in',
    'login',
    'log in',
    'age-restricted',
  ].any(lower.contains)) {
    return '该内容需要登录。请在设置中为此站点导入 cookies.txt 后重试。';
  }
  if (lower.contains('unsupported url') ||
      lower.contains('no suitable extractor')) {
    return 'yt-dlp 暂不支持此链接；可尝试单条视频链接或选择普通文件类型。';
  }
  if (['403', '429', 'forbidden'].any(lower.contains)) {
    return '网站拒绝了请求或正在限流。请稍后重试，并检查登录信息。';
  }
  if (lower.contains('space') || lower.contains('disk full')) {
    return '磁盘空间不足，请更换目录或释放空间后重试。';
  }
  if (lower.contains('permission') || lower.contains('access is denied')) {
    return '无法写入下载目录，请检查目录权限。';
  }
  if (lower.contains('resume') || lower.contains('range')) {
    return '服务器不支持继续当前下载。请使用“重新下载”从头开始。';
  }
  if (['timeout', 'network', 'resolve', 'connection'].any(lower.contains)) {
    return '网络连接失败，请检查连接后重试。';
  }
  if (['private', 'unavailable', 'removed'].any(lower.contains)) {
    return '内容不可用、已删除或当前账号无权访问。';
  }
  return '下载失败。请检查链接、引擎状态和网络后重试。';
}

String bytesLabel(num value) {
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var v = value.toDouble();
  var unit = 0;
  while (v >= 1024 && unit < units.length - 1) {
    v /= 1024;
    unit++;
  }
  return '${v.toStringAsFixed(unit == 0 ? 0 : 1)} ${units[unit]}';
}

String encodeTask(DownloadTask task) => jsonEncode(task.toJson());
