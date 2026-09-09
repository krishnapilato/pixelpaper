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
import 'widgets/album_pager.dart';
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
      // Two readers, one archive. An album's pages are already images, so it
      // gets the image path; a PDF gets PDFium. The user is not supposed to be
      // able to tell which one they are looking at.
      //
      // No Hero here, deliberately.
      //
      // The card in the archive used to fly into this page, and the flight was
      // what broke the reader: Hero builds its destination a second time
      // inside the overlay, so two PdfPagers came up, each reading the file and
      // each calling setState on the way back — and the one in the overlay was
      // already unmounted by then. "SingleChildRenderObjectElement unmounted",
      // over the whole document, reproducible on any scan large enough that
      // the read outlived the animation.
      //
      // It was buying nothing anyway: at flight time page one has not been
      // rasterised yet, so the thumbnail flew into a blank sheet. A Hero wants
      // a subtree that holds still, which is the opposite of what a reader that
      // loads its own content can offer.
      body: document.isAlbum
          ? switch (ref.watch(documentPagesProvider(document.id))) {
              AsyncData(:final value) when value.isNotEmpty => AlbumPager(
                  key: ValueKey(document.signature),
                  document: document,
                  pages: value,
                  padding: readerPadding(context),
                  onPageChanged: (index) => setState(() => _page = index),
                ),
              AsyncData() => EmptyState(
                  icon: Icons.description_outlined,
                  title: strings('viewer_open_failed'),
                  body: strings('documents_empty_body'),
                ),
              AsyncError() => EmptyState(
                  icon: Icons.error_outline_rounded,
                  title: strings('common_error'),
                  body: strings('viewer_open_failed'),
                ),
              _ => const Center(child: CircularProgressIndicator()),
            }
          : PdfPager(
              // Keyed on the signature, not on the id: coming back from the
              // editor the path is unchanged but the bytes are not, and
              // without a new key the reader would keep showing the pages it
              // read on the way in.
              key: ValueKey(document.signature),
              file: document.path,
              pageCount: pageCount,
              padding: readerPadding(context),
              onPageChanged: (index) => setState(() => _page = index),
            ),
      bottomNavigationBar: _ViewerBar(
        onEdit: () => context.push(Routes.editor(document.id)),
        onShare: () => DocumentActions.share(context, ref, [document]),
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
