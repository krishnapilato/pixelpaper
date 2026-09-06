import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/l10n/strings.dart';
import '../../../core/theme/dimens.dart';
import '../../../core/widgets/app_sheet.dart';
import '../../../core/widgets/feedback.dart';

/// Result of a text extraction: selectable, copyable, shareable.
///
/// The text is shown in a scrollable, selectable block rather than dumped into
/// the clipboard silently — people usually want one line out of a page.
Future<void> showOcrResult(
  BuildContext context,
  WidgetRef ref,
  String text,
) {
  final strings = ref.read(stringsProvider);
  final empty = text.isEmpty;
  final words = empty ? 0 : text.split(RegExp(r'\s+')).length;

  return showAppSheet<void>(
    context: context,
    child: Padding(
      padding: const EdgeInsets.only(bottom: Space.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SheetHeader(
            title: strings('ocr_title'),
            subtitle: empty
                ? strings('ocr_empty')
                : strings('ocr_summary', {'w': words, 'c': text.length}),
          ),
          if (!empty)
            Flexible(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.lg),
                child: Container(
                  padding: const EdgeInsets.all(Space.md),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(Radii.md),
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      text,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                ),
              ),
            ),
          const SizedBox(height: Space.md),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.lg),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: empty
                        ? null
                        : () async {
                            await Clipboard.setData(ClipboardData(text: text));
                            if (!context.mounted) return;
                            Navigator.pop(context);
                            showSnack(context, strings('ocr_copied'),
                                icon: Icons.check_rounded);
                          },
                    icon: const Icon(Icons.copy_rounded),
                    label: Text(strings('ocr_copy')),
                  ),
                ),
                const SizedBox(width: Space.sm),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: empty
                        ? null
                        : () => SharePlus.instance
                            .share(ShareParams(text: text)),
                    icon: const Icon(Icons.ios_share_rounded),
                    label: Text(strings('common_share')),
                  ),
                ),
              ],
            ),
          ),
          const SheetFooterSpace(),
        ],
      ),
    ),
  );
}
