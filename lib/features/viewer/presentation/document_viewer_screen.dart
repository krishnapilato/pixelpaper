import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/strings.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/dimens.dart';
import '../../../core/widgets/feedback.dart';
import '../../documents/application/document_actions.dart';
import '../../documents/application/documents_controller.dart';
import '../../documents/presentation/widgets/document_actions_sheet.dart';
import 'widgets/pdf_page_view.dart';

/// Module D, first half: read the document.
class DocumentViewerScreen extends ConsumerStatefulWidget {
  const DocumentViewerScreen({super.key, required this.documentId});

  final int documentId;

  @override
  ConsumerState<DocumentViewerScreen> createState() =>
      _DocumentViewerScreenState();
}

class _DocumentViewerScreenState extends ConsumerState<DocumentViewerScreen> {
  int _page = 0;
  String? _signature;

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(stringsProvider);
    final document = ref.watch(documentByIdProvider(widget.documentId));
    final scheme = Theme.of(context).colorScheme;

    if (document == null) {
      // The archive has not loaded yet, or the document was deleted while the
      // viewer was open.
      return Scaffold(
        appBar: AppBar(),
        body: EmptyState(
          icon: Icons.description_outlined,
          title: strings('viewer_open_failed'),
          body: strings('documents_empty_body'),
        ),
      );
    }

    final pageCount = document.pageCount > 0 ? document.pageCount : 1;

    // The file changed under the reader (the editor saved): the pager restarts,
    // so the counter has to restart with it.
    if (_signature != document.signature) {
      _signature = document.signature;
      _page = 0;
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: scheme.surface.withValues(alpha: 0.86),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              document.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              strings('viewer_page_of', {'a': _page + 1, 'b': pageCount}),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => showDocumentActions(context, ref, document),
            icon: const Icon(Icons.more_vert_rounded),
            tooltip: strings('common_details'),
          ),
          const SizedBox(width: Space.xxs),
        ],
      ),
      body: Hero(
        tag: 'document-${document.id}',
        // The card in the archive flies into the first page; once the reader
        // is up, the Hero must not constrain the pager, so the flight target
        // is the whole reader surface.
        flightShuttleBuilder: (context, animation, direction, from, to) =>
            FadeTransition(opacity: animation, child: to.widget),
        child: PdfPager(
          // Keyed on the signature, not on the id: coming back from the editor
          // the path is unchanged but the bytes are not, and without a new key
          // the reader would keep showing the pages it read on the way in.
          key: ValueKey(document.signature),
          file: document.file,
          pageCount: pageCount,
          padding: readerPadding(context),
          onPageChanged: (index) => setState(() => _page = index),
        ),
      ),
      bottomNavigationBar: _ViewerBar(
        onEdit: () => context.push(Routes.editor(document.id)),
        onShare: () => DocumentActions.share(context, [document]),
        onPrint: () => DocumentActions.print(context, ref, document),
        onDelete: () async {
          final deleted = await DocumentActions.delete(context, ref, [
            document,
          ]);
          if (deleted && context.mounted) context.pop();
        },
      ),
    );
  }
}

class _ViewerBar extends ConsumerWidget {
  const _ViewerBar({
    required this.onEdit,
    required this.onShare,
    required this.onPrint,
    required this.onDelete,
  });

  final VoidCallback onEdit;
  final VoidCallback onShare;
  final VoidCallback onPrint;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);

    return BottomAppBar(
      // The four things you do with a finished scan, each one tap away.
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _BarAction(
            icon: Icons.auto_awesome_motion_outlined,
            label: strings('common_edit'),
            onPressed: onEdit,
          ),
          _BarAction(
            icon: Icons.ios_share_rounded,
            label: strings('common_share'),
            onPressed: onShare,
          ),
          _BarAction(
            icon: Icons.print_outlined,
            label: strings('common_print'),
            onPressed: onPrint,
          ),
          _BarAction(
            icon: Icons.delete_outline_rounded,
            label: strings('common_delete'),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

class _BarAction extends StatelessWidget {
  const _BarAction({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(Radii.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Space.md,
          vertical: Space.xxs,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 2),
            Text(label, style: theme.textTheme.labelMedium),
          ],
        ),
      ),
    );
  }
}
