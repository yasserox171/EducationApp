import 'dart:convert';

import '../../core/config/app_constants.dart';
import 'enums.dart';

/// عملية مؤجَّلة في طابور الإرسال (outbox).
///
/// كل تغيير يقوم به التلميذ يُكتب محليًا فورًا، ثم تُسجَّل هنا عملية إرسال
/// تُنفَّذ عند توفّر الاتصال. `dedupKey` يمنع تراكم عشرات التحديثات لنفس
/// الدرس: التحديث الأحدث يستبدل الأقدم.
class OutboxOp {
  const OutboxOp({
    required this.id,
    required this.kind,
    required this.payload,
    required this.createdAt,
    required this.nextAttemptAt,
    this.dedupKey,
    this.attempts = 0,
    this.lastError,
    this.status = OutboxStatus.pending,
  });

  final String id;
  final OutboxKind kind;
  final Map<String, dynamic> payload;
  final String? dedupKey;
  final DateTime createdAt;
  final DateTime nextAttemptAt;
  final int attempts;
  final String? lastError;
  final OutboxStatus status;

  bool get isReady => !nextAttemptAt.isAfter(DateTime.now().toUtc());

  bool get hasExhaustedRetries => attempts >= AppConstants.maxOutboxAttempts;

  /// تأخير المحاولة القادمة: تراجع أسّي مع سقف.
  Duration backoffFor(int attemptNumber) {
    final millis =
        AppConstants.outboxBaseBackoff.inMilliseconds * (1 << attemptNumber);
    final capped = millis
        .clamp(
          AppConstants.outboxBaseBackoff.inMilliseconds,
          AppConstants.outboxMaxBackoff.inMilliseconds,
        )
        .toInt();
    return Duration(milliseconds: capped);
  }

  OutboxOp markFailed(String error) {
    final nextAttempts = attempts + 1;
    return OutboxOp(
      id: id,
      kind: kind,
      payload: payload,
      dedupKey: dedupKey,
      createdAt: createdAt,
      nextAttemptAt: DateTime.now().toUtc().add(backoffFor(nextAttempts)),
      attempts: nextAttempts,
      lastError: error,
      status: nextAttempts >= AppConstants.maxOutboxAttempts
          ? OutboxStatus.failed
          : OutboxStatus.pending,
    );
  }

  /// إعادة تفعيل عملية فشلت نهائيًا (بطلب المستخدم من شاشة الإعدادات).
  OutboxOp retryNow() => OutboxOp(
        id: id,
        kind: kind,
        payload: payload,
        dedupKey: dedupKey,
        createdAt: createdAt,
        nextAttemptAt: DateTime.now().toUtc(),
        attempts: 0,
        lastError: null,
      );

  Map<String, Object?> toDbRow() => {
        'id': id,
        'kind': kind.wire,
        'payload': jsonEncode(payload),
        'dedup_key': dedupKey,
        'created_at': createdAt.toIso8601String(),
        'next_attempt_at': nextAttemptAt.toIso8601String(),
        'attempts': attempts,
        'last_error': lastError,
        'status': status.wire,
      };

  factory OutboxOp.fromDbRow(Map<String, Object?> row) {
    final decoded = jsonDecode(row['payload'] as String? ?? '{}');
    return OutboxOp(
      id: row['id']! as String,
      kind: OutboxKind.fromWire(row['kind']! as String),
      payload: decoded is Map
          ? Map<String, dynamic>.from(decoded)
          : <String, dynamic>{},
      dedupKey: row['dedup_key'] as String?,
      createdAt: DateTime.tryParse(row['created_at'] as String? ?? '') ??
          DateTime.now().toUtc(),
      nextAttemptAt:
          DateTime.tryParse(row['next_attempt_at'] as String? ?? '') ??
              DateTime.now().toUtc(),
      attempts: (row['attempts'] as int?) ?? 0,
      lastError: row['last_error'] as String?,
      status: OutboxStatus.fromWire(row['status'] as String?),
    );
  }
}
