import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/l10n/strings.dart';
import '../../../core/theme/dimens.dart';
import '../../../core/widgets/feedback.dart';
import '../../../data/models/capture.dart';
import '../../../data/models/folder.dart';
import '../../folders/application/folders_controller.dart';
import '../../gallery/application/gallery_controller.dart';

/// The external camera owns capture. This session stays until the user leaves,
/// offering another shot without automatically reopening another application.
class SystemCameraScreen extends ConsumerStatefulWidget {
  const SystemCameraScreen({super.key});

  static Future<File?> takePage() async {
    final photo = await ImagePicker().pickImage(
      source: ImageSource.camera,
      requestFullMetadata: false,
    );
    return photo == null ? null : File(photo.path);
  }

  @override
  ConsumerState<SystemCameraScreen> createState() => _SystemCameraScreenState();
}

class _SystemCameraScreenState extends ConsumerState<SystemCameraScreen> {
  bool _busy = false;
  int _shots = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _capture());
  }

  Future<void> _capture() async {
    if (_busy || !mounted) return;
    setState(() => _busy = true);
    final folder = ref.read(currentFolderProvider(FolderKind.capture));
    try {
      final shot = await SystemCameraScreen.takePage();
      if (shot == null || !mounted) return;
      await ref.read(galleryControllerProvider.future);
      await ref
          .read(galleryControllerProvider.notifier)
          .adopt(
            File(shot.path),
            origin: CaptureSource.camera,
            folderId: folder,
          );
      if (mounted) setState(() => _shots++);
    } catch (_) {
      if (mounted) {
        showSnack(
          context,
          ref.read(stringsProvider)('camera_save_failed'),
          icon: Icons.error_outline_rounded,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(stringsProvider);
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(title: Text(strings('camera_title'))),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(Space.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.photo_camera_outlined, size: 64),
                const SizedBox(height: Space.lg),
                Text(
                  strings.plural('camera_shots', _shots),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: Space.sm),
                Text(
                  strings('camera_system_detail'),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: Space.lg),
                FilledButton.icon(
                  onPressed: _busy ? null : _capture,
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: Text(strings('camera_shutter')),
                ),
                const SizedBox(height: Space.sm),
                TextButton(
                  onPressed: _busy ? null : () => Navigator.of(context).pop(),
                  child: Text(strings('common_close')),
                ),
                if (_busy)
                  const Padding(
                    padding: EdgeInsets.all(Space.md),
                    child: CircularProgressIndicator(),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
