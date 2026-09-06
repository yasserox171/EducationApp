import 'enums.dart';

/// درس داخل مادة، موسوم بمستوى (متوسط/عالي).
class Lesson {
  const Lesson({
    required this.id,
    required this.subjectId,
    required this.title,
    required this.level,
    this.summary,
    this.position = 0,
    this.blocksCount = 0,
    this.isPublished = true,
    this.updatedAt,
  });

  final String id;
  final String subjectId;
  final String title;
  final String? summary;
  final LessonLevel level;
  final int position;
  final int blocksCount;
  final bool isPublished;
  final DateTime? updatedAt;

  factory Lesson.fromJson(Map<String, dynamic> json) => Lesson(
        id: json['id'].toString(),
        subjectId: json['subject_id'].toString(),
        title: (json['title'] ?? '') as String,
        summary: json['summary'] as String?,
        level: LessonLevel.fromWire(json['level'] as String?),
        position: (json['position'] as num?)?.toInt() ?? 0,
        blocksCount: (json['blocks_count'] as num?)?.toInt() ?? 0,
        isPublished: json['is_published'] as bool? ?? true,
        updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? ''),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'subject_id': subjectId,
        'title': title,
        'summary': summary,
        'level': level.wire,
        'position': position,
        'blocks_count': blocksCount,
        'is_published': isPublished,
        'updated_at': updatedAt?.toIso8601String(),
      };

  Map<String, Object?> toDbRow() => {
        'id': id,
        'subject_id': subjectId,
        'title': title,
        'summary': summary,
        'level': level.wire,
        'position': position,
        'blocks_count': blocksCount,
        'is_published': isPublished ? 1 : 0,
        'updated_at': updatedAt?.toIso8601String(),
        'cached_at': DateTime.now().toUtc().toIso8601String(),
      };

  factory Lesson.fromDbRow(Map<String, Object?> row) => Lesson(
        id: row['id']! as String,
        subjectId: row['subject_id']! as String,
        title: row['title']! as String,
        summary: row['summary'] as String?,
        level: LessonLevel.fromWire(row['level'] as String?),
        position: (row['position'] as int?) ?? 0,
        blocksCount: (row['blocks_count'] as int?) ?? 0,
        isPublished: (row['is_published'] as int?) != 0,
        updatedAt: DateTime.tryParse(row['updated_at'] as String? ?? ''),
      );

  Lesson copyWith({
    String? title,
    String? summary,
    LessonLevel? level,
    int? position,
    int? blocksCount,
    bool? isPublished,
  }) =>
      Lesson(
        id: id,
        subjectId: subjectId,
        title: title ?? this.title,
        summary: summary ?? this.summary,
        level: level ?? this.level,
        position: position ?? this.position,
        blocksCount: blocksCount ?? this.blocksCount,
        isPublished: isPublished ?? this.isPublished,
        updatedAt: updatedAt,
      );
}
