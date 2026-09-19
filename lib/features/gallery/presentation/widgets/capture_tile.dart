import 'package:flutter/material.dart';

import '../../../../core/theme/dimens.dart';
import '../../../../core/widgets/motion.dart';
import '../../../../data/models/capture.dart';

/// One photo in the gallery grid.
///
/// The file is decoded at the size it is drawn (`cacheWidth`), so a roll of
/// 12 MP photos costs a few megabytes of image cache instead of hundreds.
class CaptureTile extends StatelessWidget {
  const CaptureTile({
    super.key,
    required this.capture,
    required this.extent,
    required this.order,
    required this.selectionActive,
    required this.onTap,
    this.onLongPress,
  });

  final Capture capture;
  final double extent;

  /// Position in the selection (1 = picked first), or null when not
  /// selected. The number is the page this photo will be in an album.
  final int? order;
  final bool selectionActive;
  final VoidCallback onTap;

  /// Left null wherever the tile sits inside a LibraryDraggable: two
  /// long-press recognisers on one pointer cancel the drag.
  final VoidCallback? onLongPress;

  bool get selected => order != null;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final pixels = (extent * MediaQuery.devicePixelRatioOf(context)).round();

    return RepaintBoundary(
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: AnimatedScale(
          duration: Motion.quick,
          curve: Motion.standard,
          // Selected tiles shrink slightly: the gap that appears around them
          // reads as "lifted out of the sheet" without adding a border colour.
          scale: selected ? 0.9 : 1,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(Radii.sm),
                child: ColoredBox(
                  color: scheme.surfaceContainerHighest,
                  child: Hero(
                    tag: 'capture-${capture.id}',
                    child: Image.file(
                      capture.file,
                      // The path survives an edit, so without a key tied to
                      // the file's own state the grid would keep the picture
                      // it decoded before the edit.
                      key: ValueKey(capture.signature),
                      fit: BoxFit.cover,
                      cacheWidth: pixels,
                      filterQuality: FilterQuality.medium,
                      gaplessPlayback: true,
                      frameBuilder: fadeInFrame,
                      errorBuilder: (context, error, stack) => Icon(
                        Icons.broken_image_outlined,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
              AnimatedOpacity(
                opacity: selected ? 1 : 0,
                duration: Motion.quick,
                curve: Motion.standard,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(Radii.sm),
                    border: Border.all(color: scheme.primary, width: 2.5),
                  ),
                ),
              ),
              AnimatedPositioned(
                duration: Motion.base,
                curve: Motion.emphasized,
                right: 6,
                top: selectionActive ? 6 : -32,
                child: _Order(order: order),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The selection mark: an empty ring, or the photo's place in the order.
class _Order extends StatelessWidget {
  const _Order({required this.order});

  final int? order;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final order = this.order;

    return AnimatedContainer(
      duration: Motion.quick,
      curve: Motion.standard,
      height: 24,
      constraints: const BoxConstraints(minWidth: 24),
      padding: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        color: order != null
            ? scheme.primary
            : scheme.scrim.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(Radii.full),
        border: Border.all(
          color: order != null ? scheme.primary : scheme.onPrimary,
          width: 1.5,
        ),
      ),
      alignment: Alignment.center,
      child: AnimatedSwitcher(
        duration: Motion.quick,
        transitionBuilder: (child, animation) =>
            ScaleTransition(scale: animation, child: child),
        child: order == null
            ? const SizedBox.shrink()
            : Text(
                '$order',
                key: ValueKey(order),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onPrimary,
                  letterSpacing: 0,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }
}
