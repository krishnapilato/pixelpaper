import 'package:flutter/material.dart';

import '../../../../core/theme/dimens.dart';

/// Placeholder artwork for the guide, drawn with widgets instead of shipped
/// images: it stays sharp at any density, follows the theme, and adds nothing
/// to the download size.

/// A sheet of paper — the stand-in for a PDF page.
class PaperPlaceholder extends StatelessWidget {
  const PaperPlaceholder({
    super.key,
    this.width = 96,
    this.lines = 5,
    this.badge,
    this.tilt = 0,
  });

  final double width;
  final int lines;
  final Widget? badge;
  final double tilt;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Transform.rotate(
      angle: tilt,
      child: Container(
        width: width,
        height: width * 1.34,
        decoration: BoxDecoration(
          color: scheme.onSurface.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(Radii.xs),
        ),
        padding: const EdgeInsets.all(Space.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < lines; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Container(
                  height: 4,
                  width: width * (i.isEven ? 0.62 : 0.44),
                  decoration: BoxDecoration(
                    color: scheme.surface.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            const Spacer(),
            ?badge,
          ],
        ),
      ),
    );
  }
}

/// A photo tile — the stand-in for a gallery image.
class ImagePlaceholder extends StatelessWidget {
  const ImagePlaceholder({super.key, this.size = 62, this.selected = false});

  final double size;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(Radii.xs),
        border: selected ? Border.all(color: scheme.primary, width: 2.5) : null,
      ),
      child: Stack(
        children: [
          Center(
            child: Icon(
              Icons.image_outlined,
              size: size * 0.42,
              color: scheme.onSurfaceVariant,
            ),
          ),
          if (selected)
            Positioned(
              right: 4,
              top: 4,
              child: Icon(
                Icons.check_circle_rounded,
                size: 16,
                color: scheme.primary,
              ),
            ),
        ],
      ),
    );
  }
}

/// Step 1 — the scanner finding the edges of a page.
class ScanIllustration extends StatelessWidget {
  const ScanIllustration({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: 190,
      child: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 150,
              height: 190,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(Radii.md),
              ),
            ),
            const PaperPlaceholder(width: 96, tilt: -0.06),
            // Corner brackets: the visual language of automatic edge detection.
            for (final alignment in const [
              Alignment(-0.62, -0.66),
              Alignment(0.62, -0.66),
              Alignment(-0.62, 0.66),
              Alignment(0.62, 0.66),
            ])
              Align(
                alignment: alignment,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    border: Border.all(color: scheme.primary, width: 2.5),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Step 2 — the scan becoming a named PDF.
class NamingIllustration extends StatelessWidget {
  const NamingIllustration({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return SizedBox(
      height: 190,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PaperPlaceholder(
              width: 88,
              badge: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: scheme.primary,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'PDF',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onPrimary,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ),
            const SizedBox(height: Space.md),
            Container(
              width: 190,
              padding: const EdgeInsets.symmetric(
                horizontal: Space.sm,
                vertical: Space.xs,
              ),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(Radii.sm),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.edit_outlined,
                    size: 16,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: Space.xs),
                  Container(
                    height: 8,
                    width: 92,
                    decoration: BoxDecoration(
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Step 3 — raw photos selected in the gallery.
class GalleryIllustration extends StatelessWidget {
  const GalleryIllustration({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 190,
      child: Center(
        child: Wrap(
          spacing: Space.xs,
          runSpacing: Space.xs,
          alignment: WrapAlignment.center,
          children: [
            ImagePlaceholder(selected: true),
            ImagePlaceholder(),
            ImagePlaceholder(selected: true),
            ImagePlaceholder(),
            ImagePlaceholder(selected: true),
            ImagePlaceholder(),
          ],
        ),
      ),
    );
  }
}

/// Step 4 — pages being dragged into a new order.
class EditorIllustration extends StatelessWidget {
  const EditorIllustration({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: 190,
      child: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const PaperPlaceholder(width: 62, lines: 3),
            const SizedBox(width: Space.xs),
            Transform.translate(
              offset: const Offset(0, -14),
              child: Transform.rotate(
                angle: 0.08,
                child: Material(
                  elevation: 10,
                  borderRadius: BorderRadius.circular(Radii.xs),
                  shadowColor: scheme.shadow,
                  child: const PaperPlaceholder(width: 66, lines: 3),
                ),
              ),
            ),
            const SizedBox(width: Space.xs),
            const PaperPlaceholder(width: 62, lines: 3),
            const SizedBox(width: Space.xs),
            Icon(Icons.drag_indicator_rounded, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

/// Step 5 — sharing and printing the finished document.
class ShareIllustration extends StatelessWidget {
  const ShareIllustration({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    Widget bubble(IconData icon) => Container(
      margin: const EdgeInsets.symmetric(horizontal: Space.xs),
      padding: const EdgeInsets.all(Space.sm),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: scheme.onSecondaryContainer, size: 20),
    );

    return SizedBox(
      height: 190,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const PaperPlaceholder(width: 84, lines: 4),
            const SizedBox(height: Space.md),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                bubble(Icons.ios_share_rounded),
                bubble(Icons.print_outlined),
                bubble(Icons.drive_file_rename_outline_rounded),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Step 5 — folders as a rail, and the bin waiting at the bottom.
class FoldersIllustration extends StatelessWidget {
  const FoldersIllustration({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    Widget chip(String label, {bool selected = false}) => Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Space.sm,
        vertical: Space.xs,
      ),
      decoration: BoxDecoration(
        color: selected
            ? scheme.secondaryContainer
            : scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(Radii.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.folder_outlined,
            size: 16,
            color: selected
                ? scheme.onSecondaryContainer
                : scheme.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: selected
                  ? scheme.onSecondaryContainer
                  : scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );

    return SizedBox(
      height: 190,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FittedBox(
            // Two chips must never push past the card on a narrow phone.
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                chip('Fatture', selected: true),
                const SizedBox(width: Space.xs),
                chip('Università'),
              ],
            ),
          ),
          const SizedBox(height: Space.sm),
          // The page on its way down to the bin.
          Transform.rotate(
            angle: -0.12,
            child: const PaperPlaceholder(width: 54, lines: 3),
          ),
          const SizedBox(height: Space.xs),
          Icon(Icons.arrow_downward_rounded, size: 18, color: scheme.primary),
          const SizedBox(height: Space.xs),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: Space.md,
              vertical: Space.xs,
            ),
            decoration: BoxDecoration(
              color: scheme.errorContainer,
              borderRadius: BorderRadius.circular(Radii.full),
            ),
            child: Icon(
              Icons.delete_outline_rounded,
              color: scheme.onErrorContainer,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }
}

/// Step 6 — words being lifted off a photo.
class TextIllustration extends StatelessWidget {
  const TextIllustration({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return SizedBox(
      height: 190,
      child: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const ImagePlaceholder(size: 74),
            const SizedBox(width: Space.sm),
            Icon(Icons.arrow_forward_rounded, color: scheme.primary, size: 20),
            const SizedBox(width: Space.sm),
            Container(
              width: 96,
              padding: const EdgeInsets.all(Space.sm),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(Radii.xs),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Aa', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 6),
                  for (final width in const [0.9, 0.7, 0.85, 0.5])
                    Padding(
                      padding: const EdgeInsets.only(bottom: 5),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: width,
                        child: Container(
                          height: 4,
                          decoration: BoxDecoration(
                            color: scheme.onSurfaceVariant.withValues(
                              alpha: 0.5,
                            ),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
