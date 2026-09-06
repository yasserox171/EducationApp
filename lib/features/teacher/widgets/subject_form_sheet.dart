import 'package:flutter/material.dart';

import '../../../core/l10n/ar_strings.dart';
import '../../../data/models/subject.dart';

/// نتيجة نموذج المادة.
class SubjectFormResult {
  const SubjectFormResult({required this.title, this.description});

  final String title;
  final String? description;
}

/// ورقة سفلية لإضافة مادة أو تعديلها.
class SubjectFormSheet extends StatefulWidget {
  const SubjectFormSheet({this.subject, super.key});

  final Subject? subject;

  static Future<SubjectFormResult?> show(
    BuildContext context, {
    Subject? subject,
  }) =>
      showModalBottomSheet<SubjectFormResult>(
        context: context,
        isScrollControlled: true,
        builder: (sheetContext) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          child: SubjectFormSheet(subject: subject),
        ),
      );

  @override
  State<SubjectFormSheet> createState() => _SubjectFormSheetState();
}

class _SubjectFormSheetState extends State<SubjectFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.subject?.title ?? '');
    _descriptionController =
        TextEditingController(text: widget.subject?.description ?? '');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final description = _descriptionController.text.trim();
    Navigator.of(context).pop(
      SubjectFormResult(
        title: _titleController.text.trim(),
        description: description.isEmpty ? null : description,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.subject != null;

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
                isEditing ? S.editSubject : S.addSubject,
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _titleController,
                autofocus: true,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: S.subjectTitle),
                validator: (value) =>
                    (value ?? '').trim().isEmpty ? 'اسم المادة مطلوب.' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                decoration:
                    const InputDecoration(labelText: S.subjectDescription),
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
