import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// قاعدة البيانات المحلية (sqflite).
///
/// كل محتوى المستخدم الحالي فقط: عند تسجيل الخروج تُمسح الجداول عبر
/// [wipeUserData] حتى لا يرى مستخدم آخر بيانات سابقة على نفس الجهاز.
class AppDatabase {
  AppDatabase._(this.db);

  final Database db;

  static const String fileName = 'education_app.db';

  /// 1: الإصدار الأول.
  /// 2: `quiz_attempts.question_id` — فقرة الكويز صارت تحمل عدة أسئلة.
  static const int schemaVersion = 2;

  static Future<AppDatabase> open({String? overridePath}) async {
    final path = overridePath ?? p.join(await getDatabasesPath(), fileName);
    final database = await openDatabase(
      path,
      version: schemaVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        final batch = db.batch();
        for (final statement in _createStatements) {
          batch.execute(statement);
        }
        await batch.commit(noResult: true);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        // كل ترحيل خطوة واحدة، وتُطبَّق بالترتيب حتى يصل أي جهاز قديم
        // إلى الإصدار الحالي دون فقدان بيانات التلميذ.
        if (oldVersion < 2) {
          await _migrateToV2(db);
        }
      },
    );
    return AppDatabase._(database);
  }

  Future<void> close() => db.close();

  /// تُستدعى عند تسجيل الخروج. لا تمسّ الملفات على القرص —
  /// حذفها مسؤولية `MediaStore.clearAll()`.
  Future<void> wipeUserData() async {
    final batch = db.batch();
    for (final table in _userTables) {
      batch.delete(table);
    }
    await batch.commit(noResult: true);
  }

  /// نقطة دخول للاختبارات للتحقّق من ترحيل الإصدار الثاني على قاعدة
  /// أُنشئت بالمخطّط القديم.
  @visibleForTesting
  static Future<void> debugMigrateToV2(Database db) => _migrateToV2(db);

  /// إضافة عمود السؤال إلى محاولات الكويز.
  ///
  /// المحاولات القديمة سُجّلت حين كانت الفقرة تحمل سؤالًا واحدًا، فنملأ
  /// `question_id` بمعرّف الفقرة — وهو نفس ما يقرأه المحلّل الجديد للفقرات
  /// القديمة، فتبقى النتائج السابقة مرتبطة بأسئلتها.
  static Future<void> _migrateToV2(Database db) async {
    final columns = await db.rawQuery('PRAGMA table_info(quiz_attempts)');
    final hasQuestionId =
        columns.any((column) => column['name'] == 'question_id');
    if (!hasQuestionId) {
      await db.execute(
        "ALTER TABLE quiz_attempts ADD COLUMN question_id TEXT NOT NULL DEFAULT ''",
      );
    }
    await db.execute(
      "UPDATE quiz_attempts SET question_id = block_id WHERE question_id = ''",
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_attempts_question '
      'ON quiz_attempts (block_id, question_id, answered_at)',
    );
  }

  static const List<String> _userTables = [
    'subjects',
    'lessons',
    'blocks',
    'media_files',
    'lesson_downloads',
    'lesson_progress',
    'quiz_attempts',
    'subject_levels',
    'outbox',
    'kv',
  ];

  static const List<String> _createStatements = [
    '''
    CREATE TABLE subjects (
      id TEXT PRIMARY KEY,
      title TEXT NOT NULL,
      description TEXT,
      position INTEGER NOT NULL DEFAULT 0,
      lessons_count INTEGER NOT NULL DEFAULT 0,
      updated_at TEXT,
      cached_at TEXT NOT NULL
    )
    ''',
    '''
    CREATE TABLE lessons (
      id TEXT PRIMARY KEY,
      subject_id TEXT NOT NULL,
      title TEXT NOT NULL,
      summary TEXT,
      level TEXT NOT NULL,
      position INTEGER NOT NULL DEFAULT 0,
      blocks_count INTEGER NOT NULL DEFAULT 0,
      is_published INTEGER NOT NULL DEFAULT 1,
      updated_at TEXT,
      cached_at TEXT NOT NULL,
      blocks_cached_at TEXT
    )
    ''',
    'CREATE INDEX idx_lessons_subject ON lessons (subject_id, level, position)',
    '''
    CREATE TABLE blocks (
      id TEXT PRIMARY KEY,
      lesson_id TEXT NOT NULL,
      position INTEGER NOT NULL DEFAULT 0,
      type TEXT NOT NULL,
      data TEXT NOT NULL,
      updated_at TEXT
    )
    ''',
    'CREATE INDEX idx_blocks_lesson ON blocks (lesson_id, position)',
    '''
    CREATE TABLE media_files (
      block_id TEXT PRIMARY KEY,
      lesson_id TEXT NOT NULL,
      remote_url TEXT NOT NULL,
      local_path TEXT,
      bytes_total INTEGER NOT NULL DEFAULT 0,
      bytes_downloaded INTEGER NOT NULL DEFAULT 0,
      status TEXT NOT NULL DEFAULT 'none',
      error TEXT,
      updated_at TEXT NOT NULL
    )
    ''',
    'CREATE INDEX idx_media_lesson ON media_files (lesson_id)',
    '''
    CREATE TABLE lesson_downloads (
      lesson_id TEXT PRIMARY KEY,
      status TEXT NOT NULL DEFAULT 'none',
      total_bytes INTEGER NOT NULL DEFAULT 0,
      downloaded_bytes INTEGER NOT NULL DEFAULT 0,
      completed_at TEXT,
      error TEXT,
      updated_at TEXT NOT NULL
    )
    ''',
    '''
    CREATE TABLE lesson_progress (
      lesson_id TEXT PRIMARY KEY,
      subject_id TEXT NOT NULL,
      status TEXT NOT NULL DEFAULT 'not_started',
      last_block_index INTEGER NOT NULL DEFAULT 0,
      blocks_total INTEGER NOT NULL DEFAULT 0,
      completed_at TEXT,
      updated_at TEXT NOT NULL,
      is_dirty INTEGER NOT NULL DEFAULT 0
    )
    ''',
    'CREATE INDEX idx_progress_subject ON lesson_progress (subject_id, status)',
    '''
    CREATE TABLE quiz_attempts (
      id TEXT PRIMARY KEY,
      block_id TEXT NOT NULL,
      question_id TEXT NOT NULL DEFAULT '',
      lesson_id TEXT NOT NULL,
      selected_option_id TEXT NOT NULL,
      is_correct INTEGER NOT NULL DEFAULT 0,
      answered_at TEXT NOT NULL,
      is_dirty INTEGER NOT NULL DEFAULT 1
    )
    ''',
    'CREATE INDEX idx_attempts_block ON quiz_attempts (block_id, answered_at)',
    'CREATE INDEX idx_attempts_question '
        'ON quiz_attempts (block_id, question_id, answered_at)',
    '''
    CREATE TABLE subject_levels (
      subject_id TEXT PRIMARY KEY,
      level TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      is_dirty INTEGER NOT NULL DEFAULT 0
    )
    ''',
    '''
    CREATE TABLE outbox (
      id TEXT PRIMARY KEY,
      kind TEXT NOT NULL,
      payload TEXT NOT NULL,
      dedup_key TEXT,
      created_at TEXT NOT NULL,
      next_attempt_at TEXT NOT NULL,
      attempts INTEGER NOT NULL DEFAULT 0,
      last_error TEXT,
      status TEXT NOT NULL DEFAULT 'pending'
    )
    ''',
    'CREATE INDEX idx_outbox_ready ON outbox (status, next_attempt_at)',
    'CREATE INDEX idx_outbox_dedup ON outbox (dedup_key)',
    '''
    CREATE TABLE kv (
      key TEXT PRIMARY KEY,
      value TEXT NOT NULL
    )
    ''',
  ];
}
