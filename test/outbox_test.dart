import 'package:education_app/core/config/app_constants.dart';
import 'package:education_app/data/models/enums.dart';
import 'package:education_app/data/models/outbox_op.dart';
import 'package:flutter_test/flutter_test.dart';

OutboxOp buildOp({int attempts = 0}) => OutboxOp(
      id: 'op-1',
      kind: OutboxKind.lessonProgress,
      payload: const {'lesson_id': '10'},
      dedupKey: 'progress:10',
      createdAt: DateTime.utc(2026, 9, 6),
      nextAttemptAt: DateTime.utc(2026, 9, 6),
      attempts: attempts,
    );

void main() {
  group('OutboxOp', () {
    test('التراجع الأسّي يتضاعف مع كل محاولة', () {
      final op = buildOp();
      final first = op.backoffFor(1);
      final second = op.backoffFor(2);

      expect(second.inMilliseconds, first.inMilliseconds * 2);
    });

    test('التراجع لا يتجاوز السقف', () {
      final op = buildOp();

      expect(
        op.backoffFor(40).inMilliseconds,
        AppConstants.outboxMaxBackoff.inMilliseconds,
      );
    });

    test('الفشل يزيد المحاولات ويؤجّل المحاولة القادمة', () {
      final failed = buildOp().markFailed('انقطع الاتصال');

      expect(failed.attempts, 1);
      expect(failed.lastError, 'انقطع الاتصال');
      expect(failed.status, OutboxStatus.pending);
      expect(failed.nextAttemptAt.isAfter(DateTime.now().toUtc()), isTrue);
    });

    test('العملية تُوسم كفاشلة بعد استنفاد المحاولات', () {
      final op = buildOp(attempts: AppConstants.maxOutboxAttempts - 1);
      final failed = op.markFailed('خطأ خادم');

      expect(failed.attempts, AppConstants.maxOutboxAttempts);
      expect(failed.status, OutboxStatus.failed);
      expect(failed.hasExhaustedRetries, isTrue);
    });

    test('إعادة المحاولة تصفّر العدّاد وتجعلها جاهزة فورًا', () {
      final revived = buildOp(attempts: 8).markFailed('خطأ').retryNow();

      expect(revived.attempts, 0);
      expect(revived.lastError, isNull);
      expect(revived.status, OutboxStatus.pending);
      expect(revived.isReady, isTrue);
    });

    test('الذهاب إلى صف قاعدة البيانات والعودة منه يحفظ البيانات', () {
      final original = buildOp(attempts: 2);
      final restored = OutboxOp.fromDbRow(original.toDbRow());

      expect(restored.id, original.id);
      expect(restored.kind, original.kind);
      expect(restored.payload, original.payload);
      expect(restored.dedupKey, original.dedupKey);
      expect(restored.attempts, original.attempts);
      expect(restored.status, original.status);
    });
  });
}
