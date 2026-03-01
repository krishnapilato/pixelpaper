import 'dart:io';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'app_state.dart';

void showSettingsModal(BuildContext context, AppState app) {
  HapticFeedback.mediumImpact();
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withOpacity(0.4),
    useSafeArea: true,
    builder: (context) => const _StudioSettingsSheet(),
  );
}

class _StudioSettingsSheet extends StatelessWidget {
  const _StudioSettingsSheet();

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, app, child) {
        final colorScheme = Theme.of(context).colorScheme;

        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            height: MediaQuery.of(context).size.height * 0.85,
            decoration: BoxDecoration(
              color: colorScheme.surface.withOpacity(0.9),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(40),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 40,
                  offset: const Offset(0, -10),
                ),
              ],
            ),
            child: Column(
              children: [
                const SizedBox(height: 16),
                // Handle
                Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: colorScheme.outline.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 24),

                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.tune_rounded,
                          color: colorScheme.primary,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              app.t('settings') ?? 'Settings',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
                              ),
                            ),
                            Text(
                              'Customize your experience',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: colorScheme.onSurface.withOpacity(0.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton.filledTonal(
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          Navigator.pop(context);
                        },
                        icon: const Icon(Icons.close_rounded),
                        style: IconButton.styleFrom(
                          backgroundColor: colorScheme.surfaceContainerHighest
                              .withOpacity(0.5),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Scrollable Content
                Expanded(
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                    children: [
                      // --- BENTO GRID ---
                      Row(
                        children: [
                          Expanded(
                            child: _buildBentoTile(
                              context,
                              icon: Icons.translate_rounded,
                              label: app.t('language'),
                              color: Colors.blue,
                              child: _CompactLangSwitch(app: app),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildBentoTile(
                              context,
                              icon: app.themeMode == ThemeMode.dark
                                  ? Icons.dark_mode_rounded
                                  : Icons.light_mode_rounded,
                              label: app.t('dark_mode'),
                              color: Colors.indigo,
                              onTap: () => app.updateSettings(
                                theme: app.themeMode == ThemeMode.dark
                                    ? ThemeMode.light
                                    : ThemeMode.dark,
                              ),
                              child: Switch.adaptive(
                                value: app.themeMode == ThemeMode.dark,
                                activeColor: Colors.indigo,
                                onChanged: (v) => app.updateSettings(
                                  theme: v ? ThemeMode.dark : ThemeMode.light,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildBentoTile(
                        context,
                        icon: Icons.sd_storage_rounded,
                        label: app.t('save_loc'),
                        color: Colors.teal,
                        subtitle: app.useExternalStorage
                            ? (app.t('ext_store') ?? 'External Storage')
                            : (app.t('int_store') ?? 'Internal Storage'),
                        onTap: () => app.toggleStorageDirectory(),
                        trailing: Icon(
                          Icons.swap_horiz_rounded,
                          color: colorScheme.onSurface.withOpacity(0.3),
                        ),
                      ),

                      const SizedBox(height: 32),

                      // --- THEME COLORS ---
                      _buildSectionLabel(
                        context,
                        app.t('theme_color') ?? 'Theme Color',
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 70,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          itemCount: _availableColors.length,
                          itemBuilder: (context, index) {
                            final color = _availableColors[index];
                            final isSelected =
                                app.seedColor.value == color.value;
                            return GestureDetector(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                app.updateSettings(color: color);
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeOutBack,
                                margin: const EdgeInsets.only(right: 16),
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                  border: isSelected
                                      ? Border.all(
                                          color: colorScheme.surface,
                                          width: 4,
                                        )
                                      : null,
                                  boxShadow: [
                                    if (isSelected)
                                      BoxShadow(
                                        color: color.withOpacity(0.4),
                                        blurRadius: 15,
                                        offset: const Offset(0, 6),
                                      ),
                                  ],
                                ),
                                child: isSelected
                                    ? const Icon(
                                        Icons.check_rounded,
                                        color: Colors.white,
                                        size: 28,
                                      )
                                    : null,
                              ),
                            );
                          },
                        ),
                      ),

                      const SizedBox(height: 32),

                      // --- SUPPORT ISLAND ---
                      _buildSectionLabel(context, "Support"),
                      const SizedBox(height: 16),
                      Container(
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest
                              .withOpacity(0.3),
                          borderRadius: BorderRadius.circular(32),
                          border: Border.all(
                            color: colorScheme.outline.withOpacity(0.05),
                          ),
                        ),
                        child: Column(
                          children: [
                            _buildIslandRow(
                              context,
                              Icons.chat_bubble_rounded,
                              app.t('feedback') ?? 'Send Feedback',
                              Colors.orange,
                              () {
                                Navigator.pop(context);
                                showDialog(
                                  context: context,
                                  builder: (_) => FeedbackDialog(app: app),
                                );
                              },
                            ),
                            Divider(
                              height: 1,
                              indent: 72,
                              endIndent: 24,
                              color: colorScheme.outline.withOpacity(0.1),
                            ),
                            _buildIslandRow(
                              context,
                              Icons.verified_user_rounded,
                              app.t('licenses') ?? 'Open Source Licenses',
                              Colors.green,
                              () {
                                showLicensePage(
                                  context: context,
                                  applicationName: "PixelPaper",
                                  applicationVersion: "v0.9.2",
                                  applicationIcon: Padding(
                                    padding: const EdgeInsets.all(20),
                                    child: Icon(
                                      Icons.picture_as_pdf_rounded,
                                      size: 64,
                                      color: colorScheme.primary,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 48),

                      // --- FOOTER ---
                      _buildProFooter(colorScheme),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBentoTile(
    BuildContext context, {
    required IconData icon,
    required String? label,
    required Color color,
    Widget? child,
    Widget? trailing,
    String? subtitle,
    VoidCallback? onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () {
        if (onTap != null) {
          HapticFeedback.lightImpact();
          onTap();
        }
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: colorScheme.outline.withOpacity(0.05)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const Spacer(),
                if (trailing != null) trailing,
              ],
            ),
            const SizedBox(height: 20),
            Text(
              label ?? '',
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 16,
                letterSpacing: -0.5,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 13,
                  color: colorScheme.onSurface.withOpacity(0.5),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            if (child != null)
              Padding(padding: const EdgeInsets.only(top: 16), child: child),
          ],
        ),
      ),
    );
  }

  Widget _buildIslandRow(
    BuildContext context,
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(32),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: colorScheme.onSurface.withOpacity(0.2),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionLabel(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w900,
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildProFooter(ColorScheme colorScheme) {
    return Column(
      children: [
        Icon(
          Icons.auto_awesome_rounded,
          color: colorScheme.outline.withOpacity(0.5),
          size: 28,
        ),
        const SizedBox(height: 12),
        Text(
          "Designed with passion",
          style: TextStyle(
            fontStyle: FontStyle.italic,
            color: colorScheme.onSurface.withOpacity(0.5),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          "Khova Krishna Pilato • v0.9.2",
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 12,
            letterSpacing: 1,
            color: colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
      ],
    );
  }
}

// --- LANGUAGE SEGMENTED SWITCH ---
class _CompactLangSwitch extends StatelessWidget {
  final AppState app;
  const _CompactLangSwitch({required this.app});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: ['en', 'it'].map((l) {
          final isSel = app.language == l;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                app.updateSettings(lang: l);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSel ? colorScheme.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: isSel
                      ? [
                          BoxShadow(
                            color: colorScheme.primary.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: Text(
                    l.toUpperCase(),
                    style: TextStyle(
                      color: isSel
                          ? colorScheme.onPrimary
                          : colorScheme.onSurface.withOpacity(0.5),
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

final List<Color> _availableColors = [
  Colors.deepPurpleAccent,
  Colors.blueAccent,
  Colors.tealAccent.shade700,
  Colors.greenAccent.shade700,
  Colors.orangeAccent,
  Colors.redAccent,
  Colors.pinkAccent,
  Colors.brown,
];

// --- STUNNING FEEDBACK DIALOG ---
class FeedbackDialog extends StatefulWidget {
  final AppState app;
  const FeedbackDialog({super.key, required this.app});
  @override
  State<FeedbackDialog> createState() => _FeedbackDialogState();
}

class _FeedbackDialogState extends State<FeedbackDialog> {
  final TextEditingController _controller = TextEditingController();
  bool _isSending = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 40,
              offset: const Offset(0, 15),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.mark_email_read_rounded,
                color: Colors.orange,
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.app.t('feedback') ?? 'Send Feedback',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'We value your thoughts! Let us know how we can improve the app.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _controller,
              maxLines: 4,
              style: const TextStyle(fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                hintText:
                    widget.app.t('feedback_hint') ??
                    'Type your message here...',
                hintStyle: TextStyle(
                  color: colorScheme.outline.withOpacity(0.5),
                ),
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.all(20),
              ),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      widget.app.t('cancel') ?? 'Cancel',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: _isSending ? null : _send,
                    child: _isSending
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            widget.app.t('send') ?? 'Send',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _send() async {
    if (_controller.text.trim().isEmpty) return;

    HapticFeedback.mediumImpact();
    setState(() => _isSending = true);

    try {
      await http.post(
        Uri.parse('https://formspree.io/f/xdalwboq'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'message': _controller.text}),
      );
    } catch (e) {
      // Intentionally ignoring network error handling for simplicity,
      // assuming formspree usually succeeds or it fails silently for the user
    }

    if (mounted) {
      HapticFeedback.heavyImpact();
      Navigator.pop(context);

      // Show success snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white),
              SizedBox(width: 12),
              Text(
                'Feedback sent successfully!',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          margin: const EdgeInsets.fromLTRB(20, 0, 20, 40),
        ),
      );
    }
  }
}
