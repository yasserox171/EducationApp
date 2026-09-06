import 'dart:io';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/config/env.dart';
import '../../../core/error/app_exception.dart';
import '../../../core/l10n/ar_strings.dart';
import '../../../core/utils/formatters.dart';

/// اختيار فيديو من الجهاز ورفعه مع شريط تقدم وإمكانية الإلغاء.
///
/// عند نجاح الرفع تُنشأ فقرة الفيديو مباشرة وتُغلق الورقة بـ `true`.
class VideoUploadSheet extends ConsumerStatefulWidget {
  const VideoUploadSheet({required this.lessonId, super.key});

  final String lessonId;

  /// تُعيد `true` إن أُضيفت فقرة فيديو.
  static Future<bool?> show(BuildContext context, {required String lessonId}) =>
      showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        isDismissible: false,
        enableDrag: false,
        builder: (sheetContext) => VideoUploadSheet(lessonId: lessonId),
      );

  @override
  ConsumerState<VideoUploadSheet> createState() => _VideoUploadSheetState();
}

class _VideoUploadSheetState extends ConsumerState<VideoUploadSheet> {
  final _titleController = TextEditingController();
  CancelToken? _cancelToken;

  File? _file;
  int _fileSize = 0;
  double _progress = 0;
  bool _isUploading = false;
  String? _error;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    setState(() => _error = null);
    // منذ الإصدار 12: دوال ساكنة، و pickFile تُرجع ملفًا واحدًا أو null.
    final picked = await FilePicker.pickFile(type: FileType.video);
    final path = picked?.path;
    if (path == null) return;

    final file = File(path);
    final size = await file.length();

    // نتحقّق من الحجم قبل بدء الرفع بدل ترك الخادم يرفضه بعد دقائق.
    if (size > Env.maxVideoUploadBytes) {
      setState(() {
        _file = null;
        _error = 'حجم الفيديو ${Formatters.bytes(size)} — الحد الأقصى '
            '${Env.maxVideoUploadMb} م.ب.';
      });
      return;
    }

    setState(() {
      _file = file;
      _fileSize = size;
    });
  }

  Future<void> _upload() async {
    final file = _file;
    if (file == null || _isUploading) return;

    final cancelToken = CancelToken();
    setState(() {
      _isUploading = true;
      _progress = 0;
      _error = null;
      _cancelToken = cancelToken;
    });

    try {
      await ref.read(teacherRepositoryProvider).addVideoBlock(
            lessonId: widget.lessonId,
            file: file,
            title: _titleController.text.trim().isEmpty
                ? null
                : _titleController.text.trim(),
            cancelToken: cancelToken,
            onProgress: (progress) {
              if (!mounted) return;
              setState(() => _progress = progress);
            },
          );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on AppException catch (error) {
      if (!mounted) return;
      setState(() {
        _isUploading = false;
        _error = error.message;
      });
    } finally {
      _cancelToken = null;
    }
  }

  void _cancel() {
    _cancelToken?.cancel('cancelled_by_user');
    setState(() => _isUploading = false);
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
              S.addVideoBlock,
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _titleController,
              enabled: !_isUploading,
              decoration: const InputDecoration(
                labelText: 'عنوان الفيديو (اختياري)',
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _isUploading ? null : _pickFile,
              icon: const Icon(Icons.video_file_outlined),
              label: Text(_file == null ? S.pickVideo : 'تغيير الملف'),
            ),
            if (_file != null) ...[
              const SizedBox(height: 12),
              Text(
                '${_file!.path.split(Platform.pathSeparator).last}'
                ' — ${Formatters.bytes(_fileSize)}',
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(
                _error!,
                style: TextStyle(color: theme.colorScheme.error),
                textAlign: TextAlign.center,
              ),
            ],
            if (_isUploading) ...[
              const SizedBox(height: 24),
              LinearProgressIndicator(
                // القيمة السالبة تعني أن الحجم مجهول → مؤشّر غير محدّد.
                value: _progress >= 0 ? _progress : null,
              ),
              const SizedBox(height: 8),
              Text(
                _progress >= 0
                    ? '${S.uploading} ${Formatters.percent(_progress)}'
                    : S.uploading,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isUploading
                        ? _cancel
                        : () => Navigator.of(context).pop(false),
                    child: const Text(S.cancel),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _file == null || _isUploading ? null : _upload,
                    child: const Text('رفع'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
