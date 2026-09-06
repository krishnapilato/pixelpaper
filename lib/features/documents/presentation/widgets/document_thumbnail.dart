import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/dimens.dart';
import '../../../../data/models/scanned_document.dart';
import '../../../../data/providers.dart';

/// First page of a document.
///
/// The scanner hands us a page JPEG, so most documents already have a
/// thumbnail on disk and nothing is rendered here at all. When one is missing
/// (an imported or restored file) it is rasterised once, at a bounded DPI, and
/// cached — never on every scroll.
class DocumentThumbnail extends ConsumerStatefulWidget {
  const DocumentThumbnail({
    super.key,
    required this.document,
    required this.width,
    required this.height,
    this.radius = Radii.sm,
  });

  final ScannedDocument document;
  final double width;
  final double height;
  final double radius;

  @override
  ConsumerState<DocumentThumbnail> createState() => _DocumentThumbnailState();
}

class _DocumentThumbnailState extends ConsumerState<DocumentThumbnail> {
  File? _image;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(DocumentThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.document.signature != widget.document.signature) {
      _image = null;
      _failed = false;
      _resolve();
    }
  }

  Future<void> _resolve() async {
    final stored = widget.document.thumbnailPath;
    if (stored != null) {
      final file = File(stored);
      if (await file.exists()) {
        if (mounted) setState(() => _image = file);
        return;
      }
    }
    final rendered =
        await ref.read(pdfServiceProvider).thumbnail(widget.document.file);
    if (!mounted) return;
    setState(() {
      _image = rendered;
      _failed = rendered == null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final pixels = (widget.width * MediaQuery.devicePixelRatioOf(context))
        .round();
    final image = _image;

    return RepaintBoundary(
      child: Container(
        width: widget.width,
        height: widget.height,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(widget.radius),
        ),
        child: switch ((image, _failed)) {
          (final File file, _) => Image.file(
              file,
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              cacheWidth: pixels,
              filterQuality: FilterQuality.medium,
              gaplessPlayback: true,
              errorBuilder: (context, error, stack) =>
                  _Placeholder(scheme: scheme, size: widget.width),
            ),
          (null, true) => _Placeholder(scheme: scheme, size: widget.width),
          _ => const SizedBox.shrink(),
        },
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.scheme, required this.size});

  final ColorScheme scheme;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Icon(
        Icons.picture_as_pdf_outlined,
        size: size * 0.4,
        color: scheme.onSurfaceVariant,
      ),
    );
  }
}
