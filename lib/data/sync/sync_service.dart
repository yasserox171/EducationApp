import 'dart:async';

import '../../core/config/app_constants.dart';
import '../../core/error/app_exception.dart';
import '../../core/network/network_info.dart';
import '../../core/storage/dao/kv_dao.dart';
import '../../core/storage/dao/outbox_dao.dart';
import '../../core/storage/dao/progress_dao.dart';
import '../../core/utils/logger.dart';
import '../models/enums.dart';
import '../models/outbox_op.dart';
import '../models/progress.dart';
import '../remote/progress_api.dart';
import '../repositories/content_repository.dart';

/// حالة المزامنة المعروضة في الواجهة (شارة صغيرة في الشريط العلوي).
class SyncStatus {
  const SyncStatus({
    this.isSyncing = false,
    this.isOnline = true,
    this.pendingCount = 0,
    this.failedCount = 0,
    this.lastSyncAt,
    this.lastError,
  });

  final bool isSyncing;
  final bool isOnline;
  final int pendingCount;
  final int failedCount;
  final DateTime? lastSyncAt;
  final String? lastError;

  bool get hasPendingWork => pendingCount > 0 || failedCount > 0;

  SyncStatus copyWith({
    bool? isSyncing,
    bool? isOnline,
    int? pendingCount,
    int? failedCount,
    DateTime? lastSyncAt,
    String? lastError,
    bool clearError = false,
  }) =>
      SyncStatus(
        isSyncing: isSyncing ?? this.isSyncing,
        isOnline: isOnline ?? this.isOnline,
        pendingCount: pendingCount ?? this.pendingCount,
        failedCount: failedCount ?? this.failedCount,
        lastSyncAt: lastSyncAt ?? this.lastSyncAt,
        lastError: clearError ? null : (lastError ?? this.lastError),
      );
}

/// محرّك المزامنة.
///
/// اتجاهان:
/// * **دفع (push)**: عمليات طابور الإرسال (تقدّم، إجابات كويز، اختيار مستوى)
///   تُرسل بالترتيب مع تراجع أسّي عند الفشل.
/// * **سحب (pull)**: تحديث قوائم المواد/الدروس وتقدّم التلميذ من الخادم.
///   لا يُحمّل أي فيديو تلقائيًا — التحميل يدوي فقط.
class SyncService {
  SyncService({
    required OutboxDao outboxDao,
    required ProgressDao progressDao,
    required KvDao kvDao,
    required ProgressApi progressApi,
    required ContentRepository contentRepository,
    required NetworkInfo networkInfo,
  })  : _outbox = outboxDao,
        _progressDao = progressDao,
        _kv = kvDao,
        _progressApi = progressApi,
        _content = contentRepository,
        _networkInfo = networkInfo;

  final OutboxDao _outbox;
  final ProgressDao _progressDao;
  final KvDao _kv;
  final ProgressApi _progressApi;
  final ContentRepository _content;
  final NetworkInfo _networkInfo;

  final StreamController<SyncStatus> _statusController =
      StreamController<SyncStatus>.broadcast();
  StreamSubscription<bool>? _connectivitySub;
  Timer? _periodicTimer;
  bool _isRunning = false;
  bool _isSyncing = false;
  SyncStatus _status = const SyncStatus();

  Stream<SyncStatus> get statusStream => _statusController.stream;

  SyncStatus get status => _status;

  /// يبدأ الاستماع لعودة الاتصال ويجري مزامنة أولى.
  Future<void> start({bool syncNow = true}) async {
    if (_isRunning) return;
    _isRunning = true;

    _connectivitySub = _networkInfo.onStatusChange.listen((isOnline) {
      _update(_status.copyWith(isOnline: isOnline));
      if (isOnline) {
        unawaited(syncAll());
      }
    });

    _periodicTimer = Timer.periodic(
      AppConstants.minSyncInterval,
      (_) => unawaited(pushPending()),
    );

    await _refreshCounters();
    if (syncNow) {
      unawaited(syncAll());
    }
  }

  Future<void> stop() async {
    _isRunning = false;
    await _connectivitySub?.cancel();
    _connectivitySub = null;
    _periodicTimer?.cancel();
    _periodicTimer = null;
  }

  Future<void> dispose() async {
    await stop();
    await _statusController.close();
  }

  /// دورة كاملة: دفع ثم سحب.
  Future<void> syncAll() async {
    if (_isSyncing) return;
    if (!await _networkInfo.isOnline) {
      _update(_status.copyWith(isOnline: false));
      return;
    }

    _isSyncing = true;
    _update(_status.copyWith(isSyncing: true, isOnline: true, clearError: true));

    try {
      await _pushPendingInternal();
      await _pullRemote();
      _update(
        _status.copyWith(lastSyncAt: DateTime.now().toUtc(), clearError: true),
      );
      await _kv.setDateTime(KvDao.lastProgressSyncAt, DateTime.now().toUtc());
    } on AppException catch (error) {
      _update(_status.copyWith(lastError: error.message));
    } catch (error, stackTrace) {
      Log.e('SyncService', 'فشل غير متوقّع', error: error, stackTrace: stackTrace);
    } finally {
      _isSyncing = false;
      await _refreshCounters();
      _update(_status.copyWith(isSyncing: false));
    }
  }

  /// دفع الطابور فقط (يُستدعى دوريًا وبعد كل تغيير محلي).
  Future<void> pushPending() async {
    if (_isSyncing) return;
    if (!await _networkInfo.isOnline) return;
    _isSyncing = true;
    _update(_status.copyWith(isSyncing: true));
    try {
      await _pushPendingInternal();
    } finally {
      _isSyncing = false;
      await _refreshCounters();
      _update(_status.copyWith(isSyncing: false));
    }
  }

  Future<void> _pushPendingInternal() async {
    var ops = await _outbox.readyOps();
    while (ops.isNotEmpty) {
      for (final op in ops) {
        final outcome = await _sendOne(op);
        switch (outcome) {
          case _OpOutcome.success:
            await _outbox.remove(op.id);
          case _OpOutcome.permanentFailure:
            // خطأ لا تنفع معه إعادة المحاولة (بيانات مرفوضة، عنصر محذوف).
            await _outbox.remove(op.id);
          case _OpOutcome.retryable:
            // لا فائدة من متابعة بقيّة الطابور: الشبكة أو الخادم غير متاح.
            return;
        }
      }
      ops = await _outbox.readyOps();
    }
  }

  Future<_OpOutcome> _sendOne(OutboxOp op) async {
    try {
      switch (op.kind) {
        case OutboxKind.lessonProgress:
          await _progressApi.pushProgress(op.payload);
          final lessonId = op.payload['lesson_id']?.toString();
          final updatedAt =
              DateTime.tryParse(op.payload['updated_at']?.toString() ?? '');
          if (lessonId != null && updatedAt != null) {
            await _progressDao.markProgressSynced(lessonId, updatedAt);
          }
        case OutboxKind.quizAttempt:
          await _progressApi.pushQuizAttempt(op.payload);
          final attemptId = op.payload['id']?.toString();
          if (attemptId != null) {
            await _progressDao.markAttemptSynced(attemptId);
          }
        case OutboxKind.subjectLevel:
          final subjectId = op.payload['subject_id']?.toString();
          if (subjectId == null) return _OpOutcome.permanentFailure;
          await _progressApi.pushLevel(
            subjectId: subjectId,
            level: LessonLevel.fromWire(op.payload['level'] as String?),
          );
          await _progressDao.markLevelSynced(subjectId);
      }
      return _OpOutcome.success;
    } on AppException catch (error) {
      final isPermanent = error is ValidationException ||
          error is NotFoundException ||
          error is ForbiddenException;
      if (isPermanent) {
        Log.e(
          'SyncService',
          'عملية مرفوضة نهائيًا (${op.kind.wire})',
          error: error,
        );
        return _OpOutcome.permanentFailure;
      }
      await _outbox.update(op.markFailed(error.message));
      _update(_status.copyWith(lastError: error.message));
      return _OpOutcome.retryable;
    }
  }

  /// سحب المحتوى والتقدّم من الخادم.
  Future<void> _pullRemote() async {
    await _content.refreshCatalog();
    try {
      final progress = await _progressApi.fetchMyProgress();
      await _progressDao.mergeRemoteProgress(progress);
      final levels = await _progressApi.fetchMyLevels();
      await _progressDao.mergeRemoteLevels(levels);
    } on ForbiddenException {
      // حساب أستاذ: لا تقدّم شخصي — نتجاهل بهدوء.
    } on NotFoundException {
      // الخادم لا يوفّر هذه المسارات لهذا الدور.
    }
  }

  /// عدد العمليات المعلّقة (لعرض «بانتظار الإرسال: ٣»).
  Future<void> _refreshCounters() async {
    final pending = await _outbox.pendingCount();
    final failed = await _outbox.failedCount();
    final lastSync = await _kv.getDateTime(KvDao.lastProgressSyncAt);
    _update(
      _status.copyWith(
        pendingCount: pending,
        failedCount: failed,
        lastSyncAt: lastSync ?? _status.lastSyncAt,
      ),
    );
  }

  /// إعادة محاولة العمليات التي استُنفدت محاولاتها (زر في الإعدادات).
  Future<void> retryFailed() async {
    await _outbox.retryAllFailed();
    await syncAll();
  }

  /// تقدّم التلميذ عبر كل المواد (لصفحة «تقدّمي»).
  Future<List<SubjectProgressSummary>> summaries() =>
      _progressDao.subjectSummaries();

  void _update(SyncStatus next) {
    _status = next;
    if (!_statusController.isClosed) {
      _statusController.add(next);
    }
  }
}

enum _OpOutcome { success, permanentFailure, retryable }
