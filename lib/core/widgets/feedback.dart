import 'package:flutter/material.dart';

import '../theme/dimens.dart';

/// One-line confirmation toast. All copy comes from the caller so every string
/// stays in `assets/lang.json`.
void showSnack(BuildContext context, String message, {IconData? icon}) {
  final messenger = ScaffoldMessenger.of(context);
  final scheme = Theme.of(context).colorScheme;

  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      duration: const Duration(milliseconds: 2400),
      content: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: scheme.onInverseSurface),
            const SizedBox(width: Space.sm),
          ],
          Expanded(child: Text(message)),
        ],
      ),
    ),
  );
}

/// Destructive confirmation dialog. Returns true when the user commits.
Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  required String cancelLabel,
  bool destructive = true,
}) async {
  final scheme = Theme.of(context).colorScheme;

  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(cancelLabel),
        ),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(
                  backgroundColor: scheme.errorContainer,
                  foregroundColor: scheme.onErrorContainer,
                )
              : null,
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Full-screen blocking progress used while a PDF is being written.
class BusyOverlay extends StatelessWidget {
  const BusyOverlay({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(child: BusyScrim(label: label));
  }
}

/// The scrim and card of [BusyOverlay], without the positioning, so the same
/// thing can be dropped into an overlay as well as into a Stack.
class BusyScrim extends StatelessWidget {
  const BusyScrim({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ColoredBox(
      color: theme.colorScheme.scrim.withValues(alpha: 0.6),
      child: Center(
        child: Card(
          color: theme.colorScheme.surfaceContainerHigh,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Space.xl,
              vertical: Space.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  height: 28,
                  width: 28,
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
                const SizedBox(height: Space.md),
                Text(label, style: theme.textTheme.titleSmall),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Runs [work] behind a blocking spinner and hands back its result.
///
/// For the operations that genuinely take seconds and used to show nothing at
/// all: composing a PDF out of a dozen full-resolution photos, or handing a
/// large file to the share sheet, which Android copies into its cache first.
/// The screen simply sat there, so people tapped a second time.
///
/// An overlay entry rather than a dialog: this is called from callbacks that
/// may finish before a pushed route has even settled, and popping a navigator
/// that has moved on takes the wrong route with it. An entry is removed by
/// identity, so the race cannot happen.
Future<T> withBusy<T>(
  BuildContext context,
  String label,
  Future<T> Function() work,
) async {
  final overlay = Overlay.of(context, rootOverlay: true);
  final entry = OverlayEntry(
    // Absorbing pointers is the point: the work is not cancellable, so every
    // tap that lands during it is a tap the user will be surprised by later.
    builder: (context) => AbsorbPointer(child: BusyScrim(label: label)),
  );
  overlay.insert(entry);
  try {
    return await work();
  } finally {
    entry.remove();
  }
}

/// Empty-state block: icon in a tonal circle, title, body, optional action.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.action,
  });

  final IconData icon;
  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Space.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 84,
              width: 84,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHigh,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 34,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: Space.lg),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: Space.xs),
            Text(
              body,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            if (action != null) ...[const SizedBox(height: Space.lg), action!],
          ],
        ),
      ),
    );
  }
}
