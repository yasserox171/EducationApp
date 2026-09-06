import 'dart:io';

import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../../app/providers.dart';
import '../../../core/config/app_constants.dart';
import '../../../core/l10n/ar_strings.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/lesson_block.dart';
import '../../shared/providers/download_providers.dart';

/// عرض فقرة فيديو.
///
/// يفضّل الملف المحمَّل على الجهاز؛ وإن لم يكن محمَّلًا يشغّله من الشبكة.
/// ارتفاع المشغّل محدود بـ [AppConstants.maxVideoPlayerHeight] حتى لا تبتلع
/// الفيديوهات العمودية الشاشة كاملة.
class VideoBlockView extends ConsumerWidget {
  const VideoBlockView({required this.block, super.key});

  final VideoBlock block;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final localPath = ref.watch(localVideoPathProvider(block.id));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (block.title != null && block.title!.trim().isNotEmpty) ...[
          Text(block.title!, style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
        ],
        localPath.when(
          loading: () => const _PlayerBox(child: CircularProgressIndicator()),
          error: (_, __) => _PlayerBox(
            child: Text(
              'تعذّر تجهيز الفيديو.',
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ),
          data: (path) => _VideoPlayerBox(
            // المفتاح يجبر إعادة التهيئة عند تبدّل المصدر (تحميل/حذف).
            key: ValueKey(path ?? block.remoteUrl),
            localPath: path,
            remoteUrl: block.remoteUrl,
            authToken: ref.read(sessionHolderProvider).token,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(
              localPath.valueOrNull != null
                  ? Icons.offline_pin_outlined
                  : Icons.cloud_outlined,
              size: 16,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(
              localPath.valueOrNull != null
                  ? S.downloaded
                  : 'يُشغَّل من الإنترنت',
              style: theme.textTheme.bodySmall,
            ),
            if (block.durationSeconds > 0) ...[
              const SizedBox(width: 12),
              Text(
                Formatters.duration(block.durationSeconds),
                style: theme.textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _PlayerBox extends StatelessWidget {
  const _PlayerBox({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        height: 200,
        decoration: BoxDecoration(
          color: Colors.black12,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: child,
      );
}

class _VideoPlayerBox extends StatefulWidget {
  const _VideoPlayerBox({
    required this.remoteUrl,
    required this.localPath,
    this.authToken,
    super.key,
  });

  final String remoteUrl;
  final String? localPath;
  final String? authToken;

  @override
  State<_VideoPlayerBox> createState() => _VideoPlayerBoxState();
}

class _VideoPlayerBoxState extends State<_VideoPlayerBox> {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      final path = widget.localPath;
      final controller = path != null
          ? VideoPlayerController.file(File(path))
          : VideoPlayerController.networkUrl(
              Uri.parse(widget.remoteUrl),
              httpHeaders: widget.authToken == null
                  ? const {}
                  : {'Authorization': 'Bearer ${widget.authToken}'},
            );

      _videoController = controller;
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _chewieController = ChewieController(
          videoPlayerController: controller,
          autoPlay: false,
          looping: false,
          allowFullScreen: true,
          aspectRatio: controller.value.aspectRatio == 0
              ? AppConstants.defaultVideoAspectRatio
              : controller.value.aspectRatio,
          materialProgressColors: ChewieProgressColors(
            playedColor: Theme.of(context).colorScheme.primary,
          ),
        );
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = 'تعذّر تشغيل الفيديو.');
    }
  }

  @override
  void dispose() {
    _chewieController?.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return _PlayerBox(
        child: Text(
          _error!,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      );
    }

    final chewie = _chewieController;
    if (chewie == null) {
      return const _PlayerBox(child: CircularProgressIndicator());
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(
        maxHeight: AppConstants.maxVideoPlayerHeight,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: AspectRatio(
          aspectRatio: chewie.aspectRatio ?? AppConstants.defaultVideoAspectRatio,
          child: Chewie(controller: chewie),
        ),
      ),
    );
  }
}
