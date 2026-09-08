import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/strings.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/dimens.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_sheet.dart';
import '../../../../data/models/scanned_document.dart';
import '../../application/document_actions.dart';
import 'document_tile.dart';

/// Quick actions for one document.
///
/// A bottom sheet rather than a popup menu: it is reachable with the thumb on
/// a tall phone, it has room for a subtitle per action, and it is the same
/// surface the rest of the app uses for choices.
Future<void> showDocumentActions(
  BuildContext context,
  WidgetRef ref,
  ScannedDocument document,
) {
  final strings = ref.read(stringsProvider);

  return showAppSheet<void>(
    context: context,
    child: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SheetHeader(
            title: document.title,
            subtitle: documentSubtitle(strings, document),
          ),
          SheetAction(
            icon: Icons.auto_awesome_motion_outlined,
            label: strings('common_edit'),
            detail: strings('editor_hint'),
            emphasised: true,
            onTap: () {
              Navigator.pop(context);
              context.push(Routes.editor(document.id));
            },
          ),
          SheetAction(
            icon: Icons.drive_file_rename_outline_rounded,
            label: strings('common_rename'),
            onTap: () {
              Navigator.pop(context);
              DocumentActions.rename(context, ref, document);
            },
          ),
          SheetAction(
            icon: Icons.ios_share_rounded,
            label: strings('common_share'),
            onTap: () {
              Navigator.pop(context);
              DocumentActions.share(context, ref, [document]);
            },
          ),
          SheetAction(
            icon: Icons.print_outlined,
            label: strings('common_print'),
            onTap: () {
              Navigator.pop(context);
              DocumentActions.print(context, ref, document);
            },
          ),
          SheetAction(
            icon: Icons.info_outline_rounded,
            label: strings('common_details'),
            onTap: () {
              Navigator.pop(context);
              showDocumentDetails(context, ref, document);
            },
          ),
          SheetAction(
            icon: Icons.delete_outline_rounded,
            label: strings('common_delete'),
            destructive: true,
            onTap: () {
              Navigator.pop(context);
              DocumentActions.delete(context, ref, [document]);
            },
          ),
          const SheetFooterSpace(),
        ],
      ),
    ),
  );
}

Future<void> showDocumentDetails(
  BuildContext context,
  WidgetRef ref,
  ScannedDocument document,
) {
  final strings = ref.read(stringsProvider);

  return showAppSheet<void>(
    context: context,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetHeader(
          title: strings('doc_details_title'),
          subtitle: document.title,
        ),
        _DetailRow(
          label: strings('doc_detail_pages'),
          value: document.pageCount > 0 ? '${document.pageCount}' : '—',
        ),
        _DetailRow(
          label: strings('doc_detail_size'),
          value: Fmt.bytes(document.sizeBytes),
        ),
        _DetailRow(
          label: strings('doc_detail_type'),
          value: strings('doc_detail_type_value'),
        ),
        _DetailRow(
          label: strings('doc_detail_created'),
          value: Fmt.dateTime(document.createdAt),
        ),
        _DetailRow(
          label: strings('doc_detail_modified'),
          value: Fmt.dateTime(document.updatedAt),
        ),
        const SheetFooterSpace(),
      ],
    ),
  );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Space.lg,
        vertical: Space.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: theme.textTheme.bodyMedium),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: theme.textTheme.titleSmall,
            ),
          ),
        ],
      ),
    );
  }
}
