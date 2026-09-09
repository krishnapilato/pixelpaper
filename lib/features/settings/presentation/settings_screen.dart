import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:saf_util/saf_util.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/l10n/strings.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/dimens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/feedback.dart';
import '../../../data/providers.dart';
import '../../../data/services/storage_service.dart';
import '../../documents/application/documents_controller.dart';
import '../../gallery/application/gallery_controller.dart';
import '../../trash/application/trash_controller.dart';

/// Size of the regenerable preview cache.
final _cacheSizeProvider = FutureProvider.autoDispose<int>(
  (ref) => ref.watch(storageServiceProvider).previewCacheSize(),
);

/// Bytes held by the documents and photos themselves.
final _librarySizeProvider = FutureProvider.autoDispose<int>(
  (ref) => ref.watch(storageServiceProvider).librarySize(),
);

final _packageInfoProvider = FutureProvider<PackageInfo>(
  (ref) => PackageInfo.fromPlatform(),
);

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    final documents = ref.watch(documentsControllerProvider).value;
    final captures = ref.watch(galleryControllerProvider).value;
    final cache = ref.watch(_cacheSizeProvider);
    final info = ref.watch(_packageInfoProvider);
    final trashCount = ref.watch(trashCountProvider);
    final exportFolder = ref.watch(exportFolderProvider);
    final library = ref.watch(_librarySizeProvider);
    final cacheIsLarge = (cache.value ?? 0) >= StorageService.cacheNudgeBytes;

    return Scaffold(
      appBar: AppBar(title: Text(strings('settings_title'))),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          Space.md,
          Space.xs,
          Space.md,
          MediaQuery.paddingOf(context).bottom + Space.xl,
        ),
        children: [
          _Section(label: strings('settings_section_guide')),
          Card(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: ListTile(
              leading: const Icon(Icons.school_outlined),
              iconColor: Theme.of(context).colorScheme.onPrimaryContainer,
              textColor: Theme.of(context).colorScheme.onPrimaryContainer,
              title: Text(strings('settings_tutorial')),
              subtitle: Text(strings('settings_tutorial_detail')),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => context.push(Routes.tutorial),
            ),
          ),
          _Section(label: strings('settings_section_storage')),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded),
                  title: Text(strings('trash_title')),
                  subtitle: Text(strings('trash_detail')),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (trashCount > 0)
                        Text(strings.plural('trash_count', trashCount)),
                      const SizedBox(width: Space.xs),
                      const Icon(Icons.chevron_right_rounded),
                    ],
                  ),
                  onTap: () => context.push(Routes.trash),
                ),
                const Divider(indent: Space.md, endIndent: Space.md),
                ListTile(
                  leading: const Icon(Icons.folder_outlined),
                  title: Text(strings('settings_documents_count')),
                  trailing: Text('${documents?.length ?? 0}'),
                ),
                const Divider(indent: Space.md, endIndent: Space.md),
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: Text(strings('settings_images_count')),
                  trailing: Text('${captures?.length ?? 0}'),
                ),
                const Divider(indent: Space.md, endIndent: Space.md),
                ListTile(
                  leading: const Icon(Icons.sd_storage_outlined),
                  title: Text(strings('settings_space_library')),
                  trailing: Text(Fmt.bytes(library.value ?? 0)),
                ),
                const Divider(indent: Space.md, endIndent: Space.md),
                // Where "Esporta" puts the PDF. Unset by default: the app
                // should not hold a permission on a folder nobody asked it to
                // remember, so the first export asks and only a choice made
                // here makes it silent from then on.
                ListTile(
                  leading: const Icon(Icons.drive_folder_upload_outlined),
                  title: Text(strings('settings_export_folder')),
                  subtitle: Text(
                    exportFolder.value == null
                        ? strings('settings_export_folder_ask')
                        : '${exportFolder.value!.name} · '
                              '${strings('settings_export_folder_change')}',
                  ),
                  onTap: () => _pickExportFolder(context, ref, strings),
                  onLongPress: exportFolder.value == null
                      ? null
                      : () async {
                          await ref
                              .read(settingsStoreProvider)
                              .clearExportFolder();
                          ref.invalidate(exportFolderProvider);
                          if (!context.mounted) return;
                          showSnack(
                            context,
                            strings('settings_export_folder_cleared'),
                            icon: Icons.check_rounded,
                          );
                        },
                ),
                const Divider(indent: Space.md, endIndent: Space.md),
                // The cache row starts quiet and turns tonal once it is worth
                // clearing, so the button asks for attention exactly when it
                // can actually give something back.
                ListTile(
                  tileColor: cacheIsLarge
                      ? Theme.of(context).colorScheme.secondaryContainer
                      : null,
                  leading: const Icon(Icons.cleaning_services_outlined),
                  title: Text(strings('settings_clear_cache')),
                  subtitle: Text(
                    cacheIsLarge
                        ? strings('settings_cache_hint')
                        : strings('settings_clear_cache_detail'),
                  ),
                  trailing: Text(Fmt.bytes(cache.value ?? 0)),
                  onTap: () async {
                    await ref.read(storageServiceProvider).clearPreviewCache();
                    ref
                      ..invalidate(_cacheSizeProvider)
                      ..invalidate(_librarySizeProvider);
                    if (!context.mounted) return;
                    showSnack(
                      context,
                      strings('settings_cache_cleared'),
                      icon: Icons.check_rounded,
                    );
                  },
                ),
              ],
            ),
          ),
          _Section(label: strings('settings_section_author')),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context)
                        .colorScheme
                        .secondaryContainer,
                    foregroundColor: Theme.of(context)
                        .colorScheme
                        .onSecondaryContainer,
                    child: const Text('KP'),
                  ),
                  title: Text(strings('settings_author_name')),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(strings('settings_author_role')),
                      const SizedBox(height: 2),
                      // A credit, not a second author line: smaller type keeps
                      // the hierarchy honest.
                      Text(
                        strings('settings_author_idea'),
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
                  ),
                ),
                const Divider(indent: Space.md, endIndent: Space.md),
                _LinkTile(
                  icon: Icons.code_rounded,
                  label: strings('settings_author_github'),
                  detail: 'github.com/krishnapilato',
                  uri: Uri.parse('https://github.com/krishnapilato'),
                ),
                _LinkTile(
                  icon: Icons.work_outline_rounded,
                  label: strings('settings_author_linkedin'),
                  detail: 'linkedin.com/in/khovakrishnapilato',
                  uri: Uri.parse(
                    'https://www.linkedin.com/in/khovakrishnapilato/',
                  ),
                ),
                _LinkTile(
                  icon: Icons.mail_outline_rounded,
                  label: strings('settings_author_email'),
                  detail: 'krishnak.pilato@gmail.com',
                  uri: Uri(
                    scheme: 'mailto',
                    path: 'krishnak.pilato@gmail.com',
                    queryParameters: {'subject': 'PixelPaper'},
                  ),
                ),
              ],
            ),
          ),
          _Section(label: strings('settings_section_about')),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.info_outline_rounded),
                  title: Text(strings('settings_version')),
                  trailing: Text(switch (info) {
                    AsyncData(:final value) =>
                      '${value.version} (${value.buildNumber})',
                    _ => '—',
                  }),
                ),
                const Divider(indent: Space.md, endIndent: Space.md),
                // Flutter's own licence page: it enumerates every package the
                // build actually links, so the list cannot drift from the
                // dependencies the way a hand-written one would.
                ListTile(
                  leading: const Icon(Icons.balance_outlined),
                  title: Text(strings('settings_licenses')),
                  subtitle: Text(strings('settings_licenses_detail')),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => showLicensePage(
                    context: context,
                    applicationName: strings('app_name'),
                    applicationVersion: switch (info) {
                      AsyncData(:final value) => value.version,
                      _ => '',
                    },
                    applicationIcon: const Padding(
                      padding: EdgeInsets.symmetric(vertical: Space.sm),
                      child: Icon(Icons.document_scanner_outlined, size: 40),
                    ),
                    applicationLegalese:
                        '${strings('settings_author_name')}\n'
                        '${strings('settings_author_idea')}\n'
                        '${strings('settings_legalese')}',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: Space.lg),
          // The closing line of the screen, and the promise the whole app is
          // built on: nothing leaves the device.
          Column(
            children: [
              Text(
                strings('app_name'),
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 2),
              Text(
                strings('app_motto'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A row that hands a URL to the system.
///
/// `externalApplication` on purpose: a profile or a mail draft belongs in the
/// app the user already trusts for it, not in an in-app web view that cannot
/// reach their session.
class _LinkTile extends ConsumerWidget {
  const _LinkTile({
    required this.icon,
    required this.label,
    required this.detail,
    required this.uri,
  });

  final IconData icon;
  final String label;
  final String detail;
  final Uri uri;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      subtitle: Text(detail),
      trailing: const Icon(Icons.open_in_new_rounded, size: 18),
      onTap: () async {
        final strings = ref.read(stringsProvider);
        final opened = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        if (opened || !context.mounted) return;
        showSnack(
          context,
          strings('settings_link_failed'),
          icon: Icons.error_outline_rounded,
        );
      },
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Space.xs,
        Space.lg,
        Space.xs,
        Space.xs,
      ),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall,
      ),
    );
  }
}

/// Asks Android for a folder and remembers it.
///
/// `persistablePermission` is the whole point: without it the grant dies with
/// the process and the setting would be a promise the app cannot keep past the
/// next launch.
Future<void> _pickExportFolder(
  BuildContext context,
  WidgetRef ref,
  Strings strings,
) async {
  try {
    final picked = await SafUtil().pickDirectory(
      writePermission: true,
      persistablePermission: true,
    );
    if (picked == null) return; // backed out of the picker
    await ref
        .read(settingsStoreProvider)
        .setExportFolder(uri: picked.uri, name: picked.name);
    ref.invalidate(exportFolderProvider);
    if (!context.mounted) return;
    showSnack(
      context,
      strings('export_done_in', {'folder': picked.name}),
      icon: Icons.check_rounded,
    );
  } on Object {
    if (!context.mounted) return;
    showSnack(
      context,
      strings('common_error'),
      icon: Icons.error_outline_rounded,
    );
  }
}
