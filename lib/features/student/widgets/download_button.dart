import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/error/app_exception.dart';
import '../../../core/l10n/ar_strings.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/enums.dart';
import '../../shared/providers/download_providers.dart';

/// زر تحميل الدرس بحالاته الأربع: غير محمّل / جارٍ / محمّل / فشل.
///
/// التحميل يدوي دائمًا — لا شيء في التطبيق يبدأه تلقائيًا.
class DownloadButton extends ConsumerWidget {
  const DownloadButton({required this.lessonId, this.compact = true, super.key});

  final String lessonId;
  final bool compact;

  Future<void> _start(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(downloadRepositoryProvider).downloadLesson(lessonId);
      ref.invalidate(usedStorageProvider);
    } on AppException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(S.deleteDownload),
        content: const Text(S.deleteDownloadConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text(S.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(S.delete),
          ),
        ],
      ),
    );
    if (!(confirmed ?? false)) return;

    await ref.read(downloadRepositoryProvider).deleteDownload(lessonId);
    ref.invalidate(usedStorageProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final download = ref.watch(lessonDownloadProvider(lessonId)).valueOrNull;
    final status = download?.status ?? DownloadStatus.none;

    switch (status) {
      case DownloadStatus.queued:
      case DownloadStatus.downloading:
        final ratio = download?.ratio ?? 0;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 28,
              width: 28,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                value: ratio > 0 ? ratio : null,
              ),
            ),
            IconButton(
              tooltip: S.cancel,
              onPressed: () =>
                  ref.read(downloadRepositoryProvider).cancel(lessonId),
              icon: const Icon(Icons.close),
            ),
          ],
        );

      case DownloadStatus.completed:
        return IconButton(
          tooltip: '${S.downloaded} — ${S.deleteDownload}',
          color: theme.colorScheme.primary,
          onPressed: () => _delete(context, ref),
          icon: const Icon(Icons.download_done),
        );

      case DownloadStatus.failed:
        return IconButton(
          tooltip: download?.error ?? S.retry,
          color: theme.colorScheme.error,
          onPressed: () => _start(context, ref),
          icon: const Icon(Icons.refresh),
        );

      case DownloadStatus.none:
        return IconButton(
          tooltip: S.download,
          onPressed: () => _start(context, ref),
          icon: const Icon(Icons.download_outlined),
        );
    }
  }
}

/// سطر معلومات التحميل داخل شاشة الدرس (نسخة موسّعة بحجم الملفات).
class DownloadStatusLine extends ConsumerWidget {
  const DownloadStatusLine({required this.lessonId, super.key});

  final String lessonId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final download = ref.watch(lessonDownloadProvider(lessonId)).valueOrNull;
    if (download == null || download.status == DownloadStatus.none) {
      return const SizedBox.shrink();
    }

    final text = switch (download.status) {
      DownloadStatus.downloading || DownloadStatus.queued =>
        '${S.downloading} — ${Formatters.bytes(download.downloadedBytes)}'
            ' / ${Formatters.bytes(download.totalBytes)}',
      DownloadStatus.completed =>
        '${S.downloaded} (${Formatters.bytes(download.totalBytes)})',
      DownloadStatus.failed => download.error ?? S.syncFailed,
      DownloadStatus.none => '',
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          if (download.isActive)
            Expanded(
              child: LinearProgressIndicator(
                value: download.ratio > 0 ? download.ratio : null,
              ),
            )
          else
            Expanded(
              child: Text(text, style: theme.textTheme.bodySmall),
            ),
        ],
      ),
    );
  }
}
