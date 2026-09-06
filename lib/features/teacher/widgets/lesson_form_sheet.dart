import 'package:flutter/material.dart';

import '../../../core/l10n/ar_strings.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/lesson.dart';

/// نتيجة نموذج الدرس (إضافة أو تعديل).
class LessonFormResult {
  const LessonFormResult({
    required this.title,
    required this.level,
    this.summary,
  });

  final String title;
  final LessonLevel level;
  final String? summary;
}

/// ورقة سفلية لإضافة درس أو تعديله، مع اختيار الطور الدراسي.
class LessonFormSheet extends StatefulWidget {
  const LessonFormSheet({this.lesson, super.key});

  final Lesson? lesson;

  static Future<LessonFormResult?> show(
    BuildContext context, {
    Lesson? lesson,
  }) =>
      showModalBottomSheet<LessonFormResult>(
        context: context,
        isScrollControlled: true,
        builder: (sheetContext) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          child: LessonFormSheet(lesson: lesson),
        ),
      );

  @override
  State<LessonFormSheet> createState() => _LessonFormSheetState();
}

class _LessonFormSheetState extends State<LessonFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _summaryController;
  late LessonLevel _level;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.lesson?.title ?? '');
    _summaryController =
        TextEditingController(text: widget.lesson?.summary ?? '');
    _level = widget.lesson?.level ?? LessonLevel.middle;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _summaryController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(
      LessonFormResult(
        title: _titleController.text.trim(),
        level: _level,
        summary: _summaryController.text.trim().isEmpty
            ? null
            : _summaryController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.lesson != null;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                isEditing ? S.edit : S.addLesson,
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _titleController,
                autofocus: true,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: S.lessonTitle),
                validator: (value) => (value ?? '').trim().isEmpty
                    ? 'عنوان الدرس مطلوب.'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _summaryController,
                maxLines: 3,
                decoration: const InputDecoration(labelText: S.lessonSummary),
              ),
              const SizedBox(height: 20),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  S.level,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              const SizedBox(height: 8),
              SegmentedButton<LessonLevel>(
                segments: [
                  for (final level in LessonLevel.values)
                    ButtonSegment(value: level, label: Text(level.label)),
                ],
                selected: {_level},
                onSelectionChanged: (selection) =>
                    setState(() => _level = selection.first),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _submit,
                child: Text(isEditing ? S.save : S.add),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
