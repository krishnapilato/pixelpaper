import 'package:flutter/material.dart';

import '../../../../core/theme/dimens.dart';
import '../../../../data/models/scanned_document.dart';
import '../../../viewer/presentation/widgets/pdf_page_view.dart';
import '../../application/editor_controller.dart';

/// The page under the finger, shown whole.
///
/// `BoxFit.contain` on a white sheet: in an editor you are checking framing and
/// order, so a cropped preview would hide exactly what you came to look at.
class EditorPageCanvas extends StatelessWidget {
  const EditorPageCanvas({
    super.key,
    required this.document,
    required this.page,
    required this.dpi,
  });

  final ScannedDocument document;
  final EditorPageItem page;
  final double dpi;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Space.md,
        vertical: Space.xs,
      ),
      child: Center(
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(Radii.sm),
          clipBehavior: Clip.antiAlias,
          elevation: 2,
          child: switch (page) {
            EditorPageItem(blank: true) => const AspectRatio(
                aspectRatio: 0.707,
                child: SizedBox.expand(),
              ),
            EditorPageItem(:final imageBytes?) => Image.memory(
                imageBytes,
                fit: BoxFit.contain,
                gaplessPlayback: true,
              ),
            EditorPageItem(:final sourceIndex?) => PdfPageImage(
                file: document.file,
                index: sourceIndex,
                dpi: dpi,
              ),
            _ => const SizedBox.shrink(),
          },
        ),
      ),
    );
  }
}

/// One frame of the strip above the dock: tap to jump, long-press to drag.
class EditorFilmstripThumb extends StatelessWidget {
  const EditorFilmstripThumb({
    super.key,
    required this.document,
    required this.page,
    required this.position,
    required this.dpi,
    required this.current,
    required this.onTap,
  });

  final ScannedDocument document;
  final EditorPageItem page;
  final int position;
  final double dpi;
  final bool current;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Motion.quick,
        curve: Motion.enter,
        width: 64,
        padding: EdgeInsets.all(current ? 2.5 : 0),
        decoration: BoxDecoration(
          color: current ? scheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(Radii.xs + 2),
        ),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(Radii.xs),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              switch (page) {
                EditorPageItem(blank: true) => const SizedBox.expand(),
                EditorPageItem(:final imageBytes?) => Image.memory(
                    imageBytes,
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                    cacheWidth: 180,
                    gaplessPlayback: true,
                  ),
                EditorPageItem(:final sourceIndex?) => PdfPageImage(
                    file: document.file,
                    index: sourceIndex,
                    dpi: dpi,
                    fit: BoxFit.cover,
                  ),
                _ => const SizedBox.expand(),
              },
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: ColoredBox(
                  color: current
                      ? scheme.primary
                      : scheme.scrim.withValues(alpha: 0.6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      '$position',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: current ? scheme.onPrimary : Colors.white,
                        letterSpacing: 0,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
