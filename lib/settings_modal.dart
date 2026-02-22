import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'app_state.dart';

void showSettingsModal(BuildContext context, AppState app) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      final screenHeight = MediaQuery.of(context).size.height;

      return Container(
        height: screenHeight * 0.94,
        padding: const EdgeInsets.only(
          top: 15,
          left: 20,
          right: 20,
          bottom: 20,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
        ),
        child: Column(
          children: [
            // 1. MODERN DRAG HANDLE
            Container(
              width: 50,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.5),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 20),

            // 2. HEADER
            Text(
              app.t('settings'),
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 15),
            const Divider(),

            // 3. MAIN CONTENT
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                children: [
                  const SizedBox(height: 10),

                  // Language Selection
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.language, size: 28),
                    title: const Text(
                      'Language',
                      style: TextStyle(fontSize: 16),
                    ),
                    trailing: DropdownButton<String>(
                      value: app.language,
                      underline: const SizedBox(),
                      items: const [
                        DropdownMenuItem(value: 'en', child: Text('English')),
                        DropdownMenuItem(value: 'it', child: Text('Italiano')),
                      ],
                      onChanged: (v) => app.updateSettings(lang: v),
                    ),
                  ),
                  const SizedBox(height: 15),

                  // Dark Mode Toggle
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.dark_mode, size: 28),
                    title: Text(
                      app.t('dark_mode'),
                      style: const TextStyle(fontSize: 16),
                    ),
                    trailing: Switch(
                      value: app.themeMode == ThemeMode.dark,
                      onChanged: (isDark) => app.updateSettings(
                        theme: isDark ? ThemeMode.dark : ThemeMode.light,
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),

                  // Storage Location Toggle
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.folder_special, size: 28),
                    title: Text(
                      app.t('save_loc'),
                      style: const TextStyle(fontSize: 16),
                    ),
                    subtitle: Text(
                      app.useExternalStorage
                          ? app.t('ext_store')
                          : app.t('int_store'),
                    ),
                    trailing: Switch(
                      value: app.useExternalStorage,
                      onChanged: (v) => app.toggleStorageDirectory(),
                    ),
                  ),

                  const SizedBox(height: 30),

                  // THEME COLORS SECTION
                  Text(
                    app.t('theme_color'),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 15),

                  SizedBox(
                    height: 60,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      children:
                          [
                                Colors.deepPurple,
                                Colors.blue,
                                Colors.green,
                                Colors.orange,
                                Colors.red,
                                Colors.teal,
                                Colors.pink,
                                Colors.indigo,
                                Colors.brown,
                                Colors.cyan,
                              ]
                              .map(
                                (c) => Padding(
                                  padding: const EdgeInsets.only(right: 15),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(30),
                                    onTap: () => app.updateSettings(color: c),
                                    child: CircleAvatar(
                                      backgroundColor: c,
                                      radius: 25,
                                      child: app.seedColor.value == c.value
                                          ? const Icon(
                                              Icons.check,
                                              color: Colors.white,
                                              size: 24,
                                            )
                                          : null,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                    ),
                  ),
                ],
              ),
            ),

            const Divider(),

            // 4. FEEDBACK / BUG REPORT BUTTON
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.bug_report_outlined),
              title: Text(
                app.t('feedback'),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                showDialog(
                  context: context,
                  builder: (_) => FeedbackDialog(app: app),
                );
              },
            ),

            // 5. LICENSES BUTTON
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.policy_outlined),
              title: Text(
                app.t('licenses'),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                showLicensePage(
                  context: context,
                  applicationName: 'PixelPaper',
                  applicationVersion: '0.9.2',
                  applicationLegalese: '© 2026 Khova Krishna Pilato',
                );
              },
            ),

            // 6. FOOTER
            const SizedBox(height: 5),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "${app.t('author')}: Khova Krishna Pilato",
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
                Text(
                  "${app.t('version')}: 0.9.2",
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      );
    },
  );
}

// ==========================================
// INTERNAL FEEDBACK DIALOG ENGINE
// ==========================================
class FeedbackDialog extends StatefulWidget {
  final AppState app;
  const FeedbackDialog({super.key, required this.app});

  @override
  State<FeedbackDialog> createState() => _FeedbackDialogState();
}

class _FeedbackDialogState extends State<FeedbackDialog> {
  final TextEditingController _controller = TextEditingController();
  bool _isSending = false;

  Future<void> _sendFeedback() async {
    if (_controller.text.trim().isEmpty) return;

    setState(() => _isSending = true);

    // 1. Capture OS & App Data Silently
    final String os = Platform.operatingSystem; // 'android' or 'ios'
    final String osVersion = Platform.operatingSystemVersion;
    const String appVersion = "0.9.2";

    // Formatting the exact email body you will receive
    final String fullMessage =
        """
New Feedback from PixelPaper App:

App Version: $appVersion
Device OS: $os
OS Version: $osVersion

Message:
${_controller.text.trim()}
""";

    try {
      // 2. HTTP POST to Formspree Webhook
      final _ = await http.post(
        Uri.parse('https://formspree.io/f/xdalwboq'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email':
              'krishnak.pilato@gmail.com', // This helps Formspree identify the sender
          '_subject':
              'PixelPaper Bug Report - $os', // Formspree uses underscore for special fields
          'message': fullMessage,
        }),
      );

      if (mounted) {
        Navigator.pop(context); // Close dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.app.t('success')),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSending = false);
        // Show the actual error so you can debug on the new phone
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Debug Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Container(
          width: screenWidth * 0.95,
          constraints: const BoxConstraints(maxWidth: 500),
          // Prevents it from looking weird on tablets
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Section
              Text(
                widget.app.t('feedback'),
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 16),

              // Input Section
              TextField(
                controller: _controller,
                maxLines: 12,
                style: const TextStyle(fontSize: 15),
                decoration: InputDecoration(
                  hintText: widget.app.t('feedback_hint'),
                  hintStyle: TextStyle(color: theme.hintColor.withOpacity(0.4)),
                  filled: true,
                  fillColor: theme.colorScheme.surface, // Sfondo pulito
                  // Bordo quando il campo NON è selezionato
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: theme.colorScheme.outline.withOpacity(0.3),
                      width: 1.5,
                    ),
                  ),

                  // Bordo quando l'utente sta scrivendo (Focus)
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: theme.colorScheme.primary,
                      width: 2.0, // Leggermente più spesso per dare feedback
                    ),
                  ),

                  // Bordo in caso di errore (opzionale)
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: theme.colorScheme.error,
                      width: 1.5,
                    ),
                  ),

                  contentPadding: const EdgeInsets.all(
                    20,
                  ), // Più respiro al testo interno
                ),
              ),

              const SizedBox(height: 20),

              // Modern Disclaimer Box
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.auto_awesome_outlined,
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.app.t('feedback_disclaimer'),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Actions Section
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isSending ? null : () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                    child: Text(widget.app.t('cancel')),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _isSending ? null : _sendFeedback,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: _isSending
                        ? const SizedBox.shrink()
                        : const Icon(Icons.send_rounded, size: 18),
                    label: _isSending
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
            ],
          ),
        ),
      ),
    );
  }
}
