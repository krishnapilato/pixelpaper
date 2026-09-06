import 'package:flutter/material.dart';

import '../../../../core/theme/dimens.dart';
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
    required this.selected,
    required this.selectionActive,
    required this.onTap,
    this.onLongPress,
  });

  final Capture capture;
  final double extent;
  final bool selected;
  final bool selectionActive;
  final VoidCallback onTap;

  /// Left null wherever the tile sits inside a LibraryDraggable: two
  /// long-press recognisers on one pointer cancel the drag.
  final VoidCallback? onLongPress;

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
          curve: Motion.enter,
          // Selected tiles shrink slightly: the gap that appears around them
          // reads as "lifted out of the sheet" without adding a border colour.
          scale: selected ? 0.9 : 1,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(Radii.sm),
                child: Hero(
                  tag: 'capture-${capture.id}',
                  child: Image.file(
                    capture.file,
                    // The path survives an edit, so without a key tied to the
                    // file's own state the grid would keep the picture it
                    // decoded before the edit.
                    key: ValueKey(capture.signature),
                    fit: BoxFit.cover,
                    cacheWidth: pixels,
                    filterQuality: FilterQuality.medium,
                    gaplessPlayback: true,
                    errorBuilder: (context, error, stack) => ColoredBox(
                      color: scheme.surfaceContainerHighest,
                      child: Icon(
                        Icons.broken_image_outlined,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
              if (selected)
                DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(Radii.sm),
                    border: Border.all(color: scheme.primary, width: 2.5),
                  ),
                ),
              AnimatedPositioned(
                duration: Motion.quick,
                curve: Motion.enter,
                right: 6,
                top: selectionActive ? 6 : -32,
                child: _Check(selected: selected),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Check extends StatelessWidget {
  const _Check({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: 24,
      width: 24,
      decoration: BoxDecoration(
        color: selected ? scheme.primary : scheme.scrim.withValues(alpha: 0.45),
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? scheme.primary : scheme.onPrimary,
          width: 1.5,
        ),
      ),
      child: selected
          ? Icon(Icons.check_rounded, size: 15, color: scheme.onPrimary)
          : null,
    );
  }
}
