import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/config/env.dart';
import '../../../core/error/app_exception.dart';
import '../../../core/l10n/ar_strings.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/lesson_block.dart';

/// إدارة ملفات PDF المرفقة بفقرة فيديو: إضافة وحذف.
///
/// تُعيد `true` إن تغيّر شيء، ليعيد المحرّر تحميل الفقرات.
class AttachmentsSheet extends ConsumerStatefulWidget {
  const AttachmentsSheet({required this.block, super.key});

  final VideoBlock block;

  static Future<bool?> show(BuildContext context, {required VideoBlock block}) =>
      showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        builder: (sheetContext) => AttachmentsSheet(block: block),
      );

  @override
  ConsumerState<AttachmentsSheet> createState() => _AttachmentsSheetState();
}

class _AttachmentsSheetState extends ConsumerState<AttachmentsSheet> {
  late List<BlockAttachment> _attachments = [...widget.block.attachments];
  double _progress = 0;
  bool _isUploading = false;
  bool _changed = false;
  String? _error;

  VideoBlock get _currentBlock => VideoBlock(
        id: widget.block.id,
        lessonId: widget.block.lessonId,
        position: widget.block.position,
        title: widget.block.title,
        remoteUrl: widget.block.remoteUrl,
        thumbnailUrl: widget.block.thumbnailUrl,
        durationSeconds: widget.block.durationSeconds,
        sizeBytes: widget.block.sizeBytes,
        attachments: _attachments,
        updatedAt: widget.block.updatedAt,
      );

  Future<void> _pickAndUpload() async {
    setState(() => _error = null);

    final picked = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
    );
    final path = picked?.path;
    if (path == null) return;

    setState(() {
      _isUploading = true;
      _progress = 0;
    });

    try {
      final updated = await ref.read(teacherRepositoryProvider).attachPdf(
            block: _currentBlock,
            file: File(path),
            onProgress: (progress) {
              if (mounted) setState(() => _progress = progress);
            },
          );
      if (!mounted) return;
      setState(() {
        if (updated is VideoBlock) _attachments = [...updated.attachments];
        _changed = true;
      });
    } on AppException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _remove(BlockAttachment attachment) async {
    try {
      final updated = await ref.read(teacherRepositoryProvider).removeAttachment(
            block: _currentBlock,
            attachmentId: attachment.id,
          );
      if (!mounted) return;
      setState(() {
        _attachments = updated is VideoBlock
            ? [...updated.attachments]
            : _attachments
                .where((item) => item.id != attachment.id)
                .toList(growable: false);
        _changed = true;
      });
    } on AppException catch (error) {
      if (mounted) setState(() => _error = error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              S.attachments,
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              'ملفات PDF فقط، بحد أقصى ${Env.maxAttachmentMb} م.ب للملف. '
              'تُحمَّل مع الدرس عند ضغط التلميذ على «تحميل».',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            if (_attachments.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  S.noAttachments,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              for (final attachment in _attachments)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.picture_as_pdf,
                    color: theme.colorScheme.error,
                  ),
                  title: Text(
                    attachment.fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(Formatters.bytes(attachment.sizeBytes)),
                  trailing: IconButton(
                    tooltip: S.delete,
                    onPressed:
                        _isUploading ? null : () => _remove(attachment),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: theme.colorScheme.error),
                textAlign: TextAlign.center,
              ),
            ],
            if (_isUploading) ...[
              const SizedBox(height: 16),
              LinearProgressIndicator(value: _progress >= 0 ? _progress : null),
              const SizedBox(height: 6),
              Text(
                S.uploading,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: _isUploading ? null : _pickAndUpload,
              icon: const Icon(Icons.attach_file),
              label: const Text(S.addPdf),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _isUploading
                  ? null
                  : () => Navigator.of(context).pop(_changed),
              child: const Text(S.close),
            ),
          ],
        ),
      ),
    );
  }
}
