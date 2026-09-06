import 'enums.dart';

/// حالة تحميل درس كامل على الجهاز (نصوص + فيديوهات).
class LessonDownload {
  const LessonDownload({
    required this.lessonId,
    required this.status,
    this.totalBytes = 0,
    this.downloadedBytes = 0,
    this.completedAt,
    this.error,
    required this.updatedAt,
  });

  final String lessonId;
  final DownloadStatus status;
  final int totalBytes;
  final int downloadedBytes;
  final DateTime? completedAt;
  final String? error;
  final DateTime updatedAt;

  bool get isDownloaded => status == DownloadStatus.completed;

  bool get isActive =>
      status == DownloadStatus.queued || status == DownloadStatus.downloading;

  double get ratio {
    if (totalBytes <= 0) return 0;
    return (downloadedBytes / totalBytes).clamp(0.0, 1.0).toDouble();
  }

  factory LessonDownload.none(String lessonId) => LessonDownload(
        lessonId: lessonId,
        status: DownloadStatus.none,
        updatedAt: DateTime.now().toUtc(),
      );

  Map<String, Object?> toDbRow() => {
        'lesson_id': lessonId,
        'status': status.wire,
        'total_bytes': totalBytes,
        'downloaded_bytes': downloadedBytes,
        'completed_at': completedAt?.toIso8601String(),
        'error': error,
        'updated_at': updatedAt.toIso8601String(),
      };

  factory LessonDownload.fromDbRow(Map<String, Object?> row) => LessonDownload(
        lessonId: row['lesson_id']! as String,
        status: DownloadStatus.fromWire(row['status'] as String?),
        totalBytes: (row['total_bytes'] as int?) ?? 0,
        downloadedBytes: (row['downloaded_bytes'] as int?) ?? 0,
        completedAt: DateTime.tryParse(row['completed_at'] as String? ?? ''),
        error: row['error'] as String?,
        updatedAt: DateTime.tryParse(row['updated_at'] as String? ?? '') ??
            DateTime.now().toUtc(),
      );

  LessonDownload copyWith({
    DownloadStatus? status,
    int? totalBytes,
    int? downloadedBytes,
    DateTime? completedAt,
    String? error,
  }) =>
      LessonDownload(
        lessonId: lessonId,
        status: status ?? this.status,
        totalBytes: totalBytes ?? this.totalBytes,
        downloadedBytes: downloadedBytes ?? this.downloadedBytes,
        completedAt: completedAt ?? this.completedAt,
        error: error,
        updatedAt: DateTime.now().toUtc(),
      );
}

/// ملف وسائط واحد (فيديو فقرة) على الجهاز.
class MediaFile {
  const MediaFile({
    required this.blockId,
    required this.lessonId,
    required this.remoteUrl,
    required this.status,
    this.localPath,
    this.bytesTotal = 0,
    this.bytesDownloaded = 0,
    this.error,
    required this.updatedAt,
  });

  final String blockId;
  final String lessonId;
  final String remoteUrl;
  final String? localPath;
  final int bytesTotal;
  final int bytesDownloaded;
  final DownloadStatus status;
  final String? error;
  final DateTime updatedAt;

  bool get isReady => status == DownloadStatus.completed && localPath != null;

  Map<String, Object?> toDbRow() => {
        'block_id': blockId,
        'lesson_id': lessonId,
        'remote_url': remoteUrl,
        'local_path': localPath,
        'bytes_total': bytesTotal,
        'bytes_downloaded': bytesDownloaded,
        'status': status.wire,
        'error': error,
        'updated_at': updatedAt.toIso8601String(),
      };

  factory MediaFile.fromDbRow(Map<String, Object?> row) => MediaFile(
        blockId: row['block_id']! as String,
        lessonId: row['lesson_id']! as String,
        remoteUrl: row['remote_url']! as String,
        localPath: row['local_path'] as String?,
        bytesTotal: (row['bytes_total'] as int?) ?? 0,
        bytesDownloaded: (row['bytes_downloaded'] as int?) ?? 0,
        status: DownloadStatus.fromWire(row['status'] as String?),
        error: row['error'] as String?,
        updatedAt: DateTime.tryParse(row['updated_at'] as String? ?? '') ??
            DateTime.now().toUtc(),
      );
}
