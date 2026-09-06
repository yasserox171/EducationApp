import 'package:flutter/material.dart';

import '../../../core/l10n/ar_strings.dart';
import '../../../data/models/lesson_block.dart';

/// نتيجة نموذج الفقرة النصية.
class TextBlockFormResult {
  const TextBlockFormResult({required this.body, this.heading});

  final String? heading;
  final String body;
}

/// محرّر نص بسيط: عنوان اختياري + نص الفقرة.
class TextBlockForm extends StatefulWidget {
  const TextBlockForm({this.block, super.key});

  final TextBlock? block;

  static Future<TextBlockFormResult?> show(
    BuildContext context, {
    TextBlock? block,
  }) =>
      showModalBottomSheet<TextBlockFormResult>(
        context: context,
        isScrollControlled: true,
        builder: (sheetContext) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          child: TextBlockForm(block: block),
        ),
      );

  @override
  State<TextBlockForm> createState() => _TextBlockFormState();
}

class _TextBlockFormState extends State<TextBlockForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _headingController;
  late final TextEditingController _bodyController;

  @override
  void initState() {
    super.initState();
    _headingController =
        TextEditingController(text: widget.block?.heading ?? '');
    _bodyController = TextEditingController(text: widget.block?.body ?? '');
  }

  @override
  void dispose() {
    _headingController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final heading = _headingController.text.trim();
    Navigator.of(context).pop(
      TextBlockFormResult(
        heading: heading.isEmpty ? null : heading,
        body: _bodyController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  widget.block == null ? S.addTextBlock : S.edit,
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _headingController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'العنوان (اختياري)',
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _bodyController,
                  autofocus: true,
                  maxLines: 8,
                  minLines: 4,
                  decoration: const InputDecoration(labelText: 'نص الفقرة'),
                  validator: (value) =>
                      (value ?? '').trim().isEmpty ? 'نص الفقرة مطلوب.' : null,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _submit,
                  child: const Text(S.save),
                ),
              ],
            ),
          ),
        ),
      );
}
