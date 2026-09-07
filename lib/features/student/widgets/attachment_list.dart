import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/error/app_exception.dart';
import '../../../core/l10n/ar_strings.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/lesson_block.dart';
import '../../shared/providers/download_providers.dart';

/// قائمة الملفات المرفقة بفقرة الفيديو (PDF).
///
/// كل ملف يُنزَّل على حدة بزر «تنزيل»، ويُنزَّل تلقائيًا أيضًا ضمن
/// «تحميل الدرس» مع الفيديوهات، فيبقى متاحًا بلا إنترنت.
class AttachmentList extends ConsumerWidget {
  const AttachmentList({required this.block, super.key});

  final VideoBlock block;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (block.attachments.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Row(
          children: [
            Icon(
              Icons.attach_file,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(S.attachments, style: theme.textTheme.labelLarge),
          ],
        ),
        const SizedBox(height: 8),
        for (final attachment in block.attachments)
          _AttachmentTile(block: block, attachment: attachment),
      ],
    );
  }
}

class _AttachmentTile extends ConsumerStatefulWidget {
  const _AttachmentTile({required this.block, required this.attachment});

  final VideoBlock block;
  final BlockAttachment attachment;

  @override
  ConsumerState<_AttachmentTile> createState() => _AttachmentTileState();
}

class _AttachmentTileState extends ConsumerState<_AttachmentTile> {
  bool _isDownloading = false;

  Future<void> _download() async {
    setState(() => _isDownloading = true);
    try {
      await ref.read(downloadRepositoryProvider).downloadAttachment(
            lessonId: widget.block.lessonId,
            blockId: widget.block.id,
            attachment: widget.attachment,
          );
      if (!mounted) return;
      ref
        ..invalidate(localFilePathProvider(widget.attachment.id))
        ..invalidate(usedStorageProvider);
    } on AppException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final localPath =
        ref.watch(localFilePathProvider(widget.attachment.id)).valueOrNull;
    final isDownloaded = localPath != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.picture_as_pdf,
            color: isDownloaded
                ? theme.colorScheme.primary
                : theme.colorScheme.error,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.attachment.fileName,
                  style: theme.textTheme.bodyMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  isDownloaded
                      ? S.downloadedOnDevice
                      : Formatters.bytes(widget.attachment.sizeBytes),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (_isDownloading)
            const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else if (isDownloaded)
            Icon(Icons.download_done, color: theme.colorScheme.primary)
          else
            TextButton.icon(
              onPressed: _download,
              icon: const Icon(Icons.download_outlined, size: 18),
              label: const Text(S.download),
            ),
        ],
      ),
    );
  }
}
