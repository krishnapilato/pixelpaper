import 'package:flutter/material.dart';

import '../theme/dimens.dart';
import 'app_sheet.dart';

/// Single-field prompt used for naming and renaming documents.
/// Returns the trimmed value, or null when the user backs out.
Future<String?> askForText(
  BuildContext context, {
  required String title,
  required String hint,
  required String actionLabel,
  required String cancelLabel,
  String? subtitle,
  String initialValue = '',
  IconData icon = Icons.edit_outlined,
}) {
  return showAppSheet<String>(
    context: context,
    child: _TextPromptSheet(
      title: title,
      subtitle: subtitle,
      hint: hint,
      actionLabel: actionLabel,
      cancelLabel: cancelLabel,
      initialValue: initialValue,
      icon: icon,
    ),
  );
}

class _TextPromptSheet extends StatefulWidget {
  const _TextPromptSheet({
    required this.title,
    required this.hint,
    required this.actionLabel,
    required this.cancelLabel,
    required this.initialValue,
    required this.icon,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final String hint;
  final String actionLabel;
  final String cancelLabel;
  final String initialValue;
  final IconData icon;

  @override
  State<_TextPromptSheet> createState() => _TextPromptSheetState();
}

class _TextPromptSheetState extends State<_TextPromptSheet> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialValue)
        ..selection = TextSelection(
          baseOffset: 0,
          extentOffset: widget.initialValue.length,
        );

  late bool _valid = widget.initialValue.trim().isNotEmpty;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text.trim();
    if (value.isEmpty) return;
    Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SheetHeader(title: widget.title, subtitle: widget.subtitle),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.lg),
            child: TextField(
              controller: _controller,
              autofocus: true,
              textInputAction: TextInputAction.done,
              textCapitalization: TextCapitalization.sentences,
              onSubmitted: (_) => _submit(),
              onChanged: (value) {
                final next = value.trim().isNotEmpty;
                if (next != _valid) setState(() => _valid = next);
              },
              decoration: InputDecoration(
                hintText: widget.hint,
                prefixIcon: Icon(widget.icon),
              ),
            ),
          ),
          const SizedBox(height: Space.lg),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.lg),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(widget.cancelLabel),
                  ),
                ),
                const SizedBox(width: Space.sm),
                Expanded(
                  child: FilledButton(
                    onPressed: _valid ? _submit : null,
                    child: Text(widget.actionLabel),
                  ),
                ),
              ],
            ),
          ),
          const SheetFooterSpace(),
        ],
      ),
    );
  }
}
