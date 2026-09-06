/// مادة دراسية.
class Subject {
  const Subject({
    required this.id,
    required this.title,
    this.description,
    this.position = 0,
    this.lessonsCount = 0,
    this.updatedAt,
  });

  final String id;
  final String title;
  final String? description;
  final int position;

  /// عدد الدروس المنشورة كما يبلّغ عنه الخادم (لعرض سريع في القائمة).
  final int lessonsCount;
  final DateTime? updatedAt;

  factory Subject.fromJson(Map<String, dynamic> json) => Subject(
        id: json['id'].toString(),
        title: (json['title'] ?? json['name'] ?? '') as String,
        description: json['description'] as String?,
        position: (json['position'] as num?)?.toInt() ?? 0,
        lessonsCount: (json['lessons_count'] as num?)?.toInt() ?? 0,
        updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? ''),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'position': position,
        'lessons_count': lessonsCount,
        'updated_at': updatedAt?.toIso8601String(),
      };

  Map<String, Object?> toDbRow() => {
        'id': id,
        'title': title,
        'description': description,
        'position': position,
        'lessons_count': lessonsCount,
        'updated_at': updatedAt?.toIso8601String(),
        'cached_at': DateTime.now().toUtc().toIso8601String(),
      };

  factory Subject.fromDbRow(Map<String, Object?> row) => Subject(
        id: row['id']! as String,
        title: row['title']! as String,
        description: row['description'] as String?,
        position: (row['position'] as int?) ?? 0,
        lessonsCount: (row['lessons_count'] as int?) ?? 0,
        updatedAt: DateTime.tryParse(row['updated_at'] as String? ?? ''),
      );

  Subject copyWith({
    String? title,
    String? description,
    int? position,
    int? lessonsCount,
  }) =>
      Subject(
        id: id,
        title: title ?? this.title,
        description: description ?? this.description,
        position: position ?? this.position,
        lessonsCount: lessonsCount ?? this.lessonsCount,
        updatedAt: updatedAt,
      );
}
