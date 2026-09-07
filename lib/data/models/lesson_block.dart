import 'dart:convert';

import 'enums.dart';

/// فقرة داخل الدرس. النوع محدَّد عبر `sealed class` ليجبر `switch` على
/// تغطية كل الأنواع عند العرض أو التحرير.
///
/// شكل التخزين في قاعدة البيانات المحلية: أعمدة مشتركة (id, lesson_id,
/// position, type) + عمود `data` يحمل JSON الخاص بالنوع.
sealed class LessonBlock {
  const LessonBlock({
    required this.id,
    required this.lessonId,
    required this.position,
    this.updatedAt,
  });

  final String id;
  final String lessonId;
  final int position;
  final DateTime? updatedAt;

  BlockType get type;

  /// الحقول الخاصة بالنوع فقط (بدون الحقول المشتركة).
  Map<String, dynamic> dataToJson();

  Map<String, dynamic> toJson() => {
        'id': id,
        'lesson_id': lessonId,
        'position': position,
        'type': type.wire,
        'data': dataToJson(),
        'updated_at': updatedAt?.toIso8601String(),
      };

  Map<String, Object?> toDbRow() => {
        'id': id,
        'lesson_id': lessonId,
        'position': position,
        'type': type.wire,
        'data': jsonEncode(dataToJson()),
        'updated_at': updatedAt?.toIso8601String(),
      };

  factory LessonBlock.fromJson(Map<String, dynamic> json) {
    final id = json['id'].toString();
    final lessonId = json['lesson_id'].toString();
    final position = (json['position'] as num?)?.toInt() ?? 0;
    final updatedAt = DateTime.tryParse(json['updated_at']?.toString() ?? '');
    final data = json['data'] is Map
        ? Map<String, dynamic>.from(json['data'] as Map)
        : <String, dynamic>{};

    return _build(
      type: BlockType.fromWire(json['type'] as String?),
      id: id,
      lessonId: lessonId,
      position: position,
      updatedAt: updatedAt,
      data: data,
    );
  }

  factory LessonBlock.fromDbRow(Map<String, Object?> row) {
    final rawData = row['data'] as String? ?? '{}';
    final decoded = jsonDecode(rawData);
    return _build(
      type: BlockType.fromWire(row['type'] as String?),
      id: row['id']! as String,
      lessonId: row['lesson_id']! as String,
      position: (row['position'] as int?) ?? 0,
      updatedAt: DateTime.tryParse(row['updated_at'] as String? ?? ''),
      data: decoded is Map
          ? Map<String, dynamic>.from(decoded)
          : <String, dynamic>{},
    );
  }

  static LessonBlock _build({
    required BlockType type,
    required String id,
    required String lessonId,
    required int position,
    required DateTime? updatedAt,
    required Map<String, dynamic> data,
  }) {
    switch (type) {
      case BlockType.text:
        return TextBlock(
          id: id,
          lessonId: lessonId,
          position: position,
          updatedAt: updatedAt,
          heading: data['heading'] as String?,
          body: (data['body'] ?? '') as String,
        );
      case BlockType.video:
        return VideoBlock(
          id: id,
          lessonId: lessonId,
          position: position,
          updatedAt: updatedAt,
          title: data['title'] as String?,
          remoteUrl: (data['url'] ?? data['remote_url'] ?? '') as String,
          thumbnailUrl: data['thumbnail_url'] as String?,
          durationSeconds: (data['duration_seconds'] as num?)?.toInt() ?? 0,
          sizeBytes: (data['size_bytes'] as num?)?.toInt() ?? 0,
        );
      case BlockType.quiz:
        return QuizBlock(
          id: id,
          lessonId: lessonId,
          position: position,
          updatedAt: updatedAt,
          questions: QuizQuestion.listFromData(data, fallbackId: id),
        );
    }
  }
}

/// فقرة نصية: عنوان اختياري + نص.
class TextBlock extends LessonBlock {
  const TextBlock({
    required super.id,
    required super.lessonId,
    required super.position,
    required this.body,
    this.heading,
    super.updatedAt,
  });

  final String? heading;
  final String body;

  @override
  BlockType get type => BlockType.text;

  @override
  Map<String, dynamic> dataToJson() => {
        'heading': heading,
        'body': body,
      };

  TextBlock copyWith({String? heading, String? body, int? position}) =>
      TextBlock(
        id: id,
        lessonId: lessonId,
        position: position ?? this.position,
        heading: heading ?? this.heading,
        body: body ?? this.body,
        updatedAt: updatedAt,
      );
}

/// فقرة فيديو. `remoteUrl` رابط الخادم؛ المسار المحلي يُقرأ من جدول الوسائط
/// وليس جزءًا من الفقرة نفسها.
class VideoBlock extends LessonBlock {
  const VideoBlock({
    required super.id,
    required super.lessonId,
    required super.position,
    required this.remoteUrl,
    this.title,
    this.thumbnailUrl,
    this.durationSeconds = 0,
    this.sizeBytes = 0,
    super.updatedAt,
  });

  final String? title;
  final String remoteUrl;
  final String? thumbnailUrl;
  final int durationSeconds;
  final int sizeBytes;

  @override
  BlockType get type => BlockType.video;

  @override
  Map<String, dynamic> dataToJson() => {
        'title': title,
        'url': remoteUrl,
        'thumbnail_url': thumbnailUrl,
        'duration_seconds': durationSeconds,
        'size_bytes': sizeBytes,
      };
}

/// خيار واحد في سؤال الكويز.
class QuizOption {
  const QuizOption({required this.id, required this.text});

  final String id;
  final String text;

  factory QuizOption.fromJson(Map<String, dynamic> json) => QuizOption(
        id: json['id'].toString(),
        text: (json['text'] ?? '') as String,
      );

  Map<String, dynamic> toJson() => {'id': id, 'text': text};
}

/// سؤال واحد داخل فقرة كويز: نصّ + اختيارات + إجابة صحيحة واحدة.
///
/// `correctOptionId` يكون `null` إن اختار الخادم عدم إرسال الإجابة الصحيحة
/// مسبقًا؛ عندها لا يمكن التصحيح على الجهاز. أما في الوضع الأوفلاين
/// فالإجابة الصحيحة مطلوبة داخل السؤال ليعمل التصحيح محليًا.
class QuizQuestion {
  const QuizQuestion({
    required this.id,
    required this.question,
    required this.options,
    this.correctOptionId,
    this.explanation,
  });

  final String id;
  final String question;
  final List<QuizOption> options;
  final String? correctOptionId;
  final String? explanation;

  bool isCorrect(String optionId) =>
      correctOptionId != null && correctOptionId == optionId;

  /// نصّ الخيار الصحيح (لعرضه في بطاقة النتيجة عند الخطأ).
  String? get correctOptionText {
    for (final option in options) {
      if (option.id == correctOptionId) return option.text;
    }
    return null;
  }

  factory QuizQuestion.fromJson(Map<String, dynamic> json, {String? fallbackId}) {
    final rawOptions = json['options'];
    return QuizQuestion(
      id: json['id']?.toString() ?? fallbackId ?? '',
      question: (json['question'] ?? '') as String,
      options: rawOptions is List
          ? rawOptions
              .whereType<Map>()
              .map((e) => QuizOption.fromJson(Map<String, dynamic>.from(e)))
              .toList(growable: false)
          : const <QuizOption>[],
      correctOptionId: json['correct_option_id']?.toString(),
      explanation: json['explanation'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'question': question,
        'options': options.map((e) => e.toJson()).toList(growable: false),
        'correct_option_id': correctOptionId,
        'explanation': explanation,
      };

  /// يقرأ أسئلة الفقرة من `data` بالشكلين معًا:
  /// * الجديد: `{"questions": [ {...}, {...} ]}`
  /// * القديم (سؤال واحد في جذر البيانات): `{"question": "...", "options": [...]}`
  ///
  /// الشكل القديم يُقرأ كسؤال واحد معرّفه هو معرّف الفقرة، فتبقى محاولات
  /// التلاميذ المسجَّلة سابقًا مرتبطة بسؤالها الصحيح.
  static List<QuizQuestion> listFromData(
    Map<String, dynamic> data, {
    required String fallbackId,
  }) {
    final raw = data['questions'];
    if (raw is List && raw.isNotEmpty) {
      return raw
          .whereType<Map>()
          .map((e) => QuizQuestion.fromJson(Map<String, dynamic>.from(e)))
          .where((question) => question.id.isNotEmpty)
          .toList(growable: false);
    }
    if (data['question'] != null || data['options'] != null) {
      return [QuizQuestion.fromJson(data, fallbackId: fallbackId)];
    }
    return const <QuizQuestion>[];
  }
}

/// فقرة كويز: سؤال واحد أو أكثر. لا تُعرض أي نتيجة للتلميذ إلا بعد
/// إجابته على كل أسئلة الفقرة.
class QuizBlock extends LessonBlock {
  const QuizBlock({
    required super.id,
    required super.lessonId,
    required super.position,
    required this.questions,
    super.updatedAt,
  });

  final List<QuizQuestion> questions;

  int get questionsCount => questions.length;

  @override
  BlockType get type => BlockType.quiz;

  @override
  Map<String, dynamic> dataToJson() => {
        'questions': questions.map((e) => e.toJson()).toList(growable: false),
      };
}
