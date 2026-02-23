import 'dart:io';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'app_state.dart';

void showSettingsModal(BuildContext context, AppState app) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      final theme = Theme.of(context);
      final colorScheme = theme.colorScheme;
      final screenHeight = MediaQuery.of(context).size.height;

      return Container(
        height: screenHeight * 0.94,
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            // Elegant Drag Handle
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.onSurfaceVariant.withOpacity(0.3),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 20),

            // Header
            Text(
              app.t('settings'),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.8,
              ),
            ),
            const SizedBox(height: 10),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                physics: const BouncingScrollPhysics(),
                children: [
                  const SizedBox(height: 20),

                  // --- APPEARANCE GROUP ---
                  _buildSectionLabel(app.t('appearance')),
                  _buildGroup([
                    _buildSettingRow(
                      context,
                      icon: Icons.translate_rounded,
                      iconColor: Colors.blue,
                      title: app.t('language'),
                      trailing: DropdownButton<String>(
                        value: app.language,
                        underline: const SizedBox(),
                        icon: const Icon(Icons.expand_more_rounded, size: 20),
                        borderRadius: BorderRadius.circular(16),
                        items: const [
                          DropdownMenuItem(
                            value: 'en',
                            child: Text('English  '),
                          ),
                          DropdownMenuItem(
                            value: 'it',
                            child: Text('Italiano  '),
                          ),
                        ],
                        onChanged: (v) {
                          HapticFeedback.selectionClick();
                          app.updateSettings(lang: v);
                        },
                      ),
                    ),
                    _buildSettingRow(
                      context,
                      icon: Icons.dark_mode_rounded,
                      iconColor: Colors.amber,
                      title: app.t('dark_mode'),
                      trailing: Switch.adaptive(
                        value: app.themeMode == ThemeMode.dark,
                        activeColor: colorScheme.primary,
                        onChanged: (v) {
                          HapticFeedback.lightImpact();
                          app.updateSettings(
                            theme: v ? ThemeMode.dark : ThemeMode.light,
                          );
                        },
                      ),
                    ),
                  ]),

                  const SizedBox(height: 24),

                  // --- THEME COLOR (Special treatment) ---
                  _buildSectionLabel(app.t('theme_color')),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceVariant.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: SizedBox(
                      height: 50,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _availableColors.length,
                        itemBuilder: (context, index) {
                          final color = _availableColors[index];
                          final isSelected = app.seedColor.value == color.value;
                          return GestureDetector(
                            onTap: () {
                              HapticFeedback.mediumImpact();
                              app.updateSettings(color: color);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: const EdgeInsets.only(right: 14),
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected
                                      ? color
                                      : Colors.transparent,
                                  width: 3,
                                ),
                              ),
                              padding: const EdgeInsets.all(3),
                              child: CircleAvatar(
                                backgroundColor: color,
                                child: isSelected
                                    ? const Icon(
                                        Icons.check_rounded,
                                        color: Colors.white,
                                        size: 20,
                                      )
                                    : null,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // --- STORAGE GROUP ---
                  _buildSectionLabel(app.t('storage')),
                  _buildGroup([
                    _buildSettingRow(
                      context,
                      icon: Icons.folder_rounded,
                      iconColor: Colors.orange,
                      title: app.t('save_loc'),
                      subtitle: app.useExternalStorage
                          ? app.t('ext_store')
                          : app.t('int_store'),
                      trailing: Switch.adaptive(
                        value: app.useExternalStorage,
                        onChanged: (v) {
                          HapticFeedback.mediumImpact();
                          app.toggleStorageDirectory();
                        },
                      ),
                    ),
                  ]),

                  const SizedBox(height: 24),

                  // --- SUPPORT GROUP ---
                  _buildSectionLabel(app.t('support')),
                  _buildGroup([
                    _buildSettingRow(
                      context,
                      icon: Icons.chat_bubble_rounded,
                      iconColor: Colors.teal,
                      title: app.t('feedback'),
                      onTap: () => showDialog(
                        context: context,
                        builder: (_) => FeedbackDialog(app: app),
                      ),
                    ),
                    _buildSettingRow(
                      context,
                      icon: Icons.verified_user_rounded,
                      iconColor: Colors.green,
                      title: app.t('licenses'),
                      showArrow: true,
                      onTap: () => showLicensePage(
                        context: context,
                        applicationName: 'PixelPaper',
                        applicationVersion: '0.9.2',
                      ),
                    ),
                  ]),

                  const SizedBox(height: 40),

                  // --- SIGNATURE FOOTER ---
                  Column(
                    children: [
                      Text(
                        "PixelPaper",
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface.withOpacity(0.5),
                        ),
                      ),
                      Text(
                        "${app.t('version')} 0.9.2",
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface.withOpacity(0.4),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.auto_awesome_rounded,
                            size: 14,
                            color: colorScheme.primary.withOpacity(0.4),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "Handcrafted by Khova Krishna Pilato",
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontStyle: FontStyle.italic,
                              color: colorScheme.onSurface.withOpacity(0.35),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}

// --- MODERN UI HELPERS ---

Widget _buildSectionLabel(String text) {
  return Padding(
    padding: const EdgeInsets.only(left: 16, bottom: 10),
    child: Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: Colors.grey,
        letterSpacing: 1.2,
      ),
    ),
  );
}

Widget _buildGroup(List<Widget> children) {
  return Container(
    decoration: BoxDecoration(
      color: Colors.grey.withOpacity(0.08),
      borderRadius: BorderRadius.circular(24),
    ),
    child: Column(children: children),
  );
}

Widget _buildSettingRow(
  BuildContext context, {
  required IconData icon,
  required Color iconColor,
  required String title,
  String? subtitle,
  Widget? trailing,
  bool showArrow = false,
  VoidCallback? onTap,
}) {
  return ListTile(
    onTap: onTap,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    leading: Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: iconColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: iconColor, size: 22),
    ),
    title: Text(
      title,
      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
    ),
    subtitle: subtitle != null
        ? Text(subtitle, style: const TextStyle(fontSize: 13))
        : null,
    trailing:
        trailing ??
        (showArrow
            ? const Icon(Icons.chevron_right_rounded, color: Colors.grey)
            : null),
  );
}

final List<Color> _availableColors = [
  Colors.deepPurple,
  Colors.blue,
  Colors.teal,
  Colors.green,
  Colors.orange,
  Colors.red,
  Colors.pink,
  Colors.brown,
];

// --- FEEDBACK DIALOG REDESIGN ---

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
    final theme = Theme.of(context);
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
      child: AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
        title: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.edit_note_rounded,
                color: theme.colorScheme.primary,
                size: 28,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.app.t('feedback'),
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ],
        ),
        content: TextField(
          controller: _controller,
          maxLines: 4,
          autofocus: true,
          style: const TextStyle(fontSize: 15),
          decoration: InputDecoration(
            hintText: widget.app.t('feedback_hint'),
            filled: true,
            fillColor: theme.colorScheme.surfaceVariant.withOpacity(0.4),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.all(20),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              widget.app.t('cancel'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          ElevatedButton(
            onPressed: _isSending ? null : _send,
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: _isSending
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    widget.app.t('send'),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _send() async {
    if (_controller.text.trim().isEmpty) return;
    setState(() => _isSending = true);
    try {
      await http.post(
        Uri.parse('https://formspree.io/f/xdalwboq'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': 'app-feedback@pixelpaper.com',
          '_subject': 'PixelPaper - ${Platform.operatingSystem} Feedback',
          'message': _controller.text,
        }),
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.app.t('success')),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.green,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _isSending = false);
    }
  }
}
