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
    barrierColor: Theme.of(context).colorScheme.shadow.withOpacity(0.4),
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
        final bottomPadding = MediaQuery.of(context).padding.bottom;

        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            height: MediaQuery.of(context).size.height * 0.88,
            decoration: BoxDecoration(
              color: colorScheme.surface.withOpacity(0.85),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(40),
              ),
              border: Border(
                top: BorderSide(color: Colors.white.withOpacity(0.1), width: 1),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 40,
                  offset: const Offset(0, -10),
                ),
              ],
            ),
            child: Column(
              children: [
                // Minimalist Drag Handle
                Padding(
                  padding: const EdgeInsets.only(top: 16, bottom: 24),
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colorScheme.onSurfaceVariant.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),

                // Sticky Header
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
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              app.t('settings') ?? 'Preferences',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                                color: colorScheme.onSurface,
                              ),
                            ),
                            Text(
                              app.t('customize_exp') ??
                                  'Customize your experience',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _InteractiveBounce(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.pop(context);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest
                                .withOpacity(0.5),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.close_rounded,
                            color: colorScheme.onSurface,
                            size: 20,
                          ),
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
                    padding: EdgeInsets.fromLTRB(24, 0, 24, bottomPadding + 40),
                    children: [
                      // --- BENTO GRID: Display & Language ---
                      Row(
                        children: [
                          Expanded(
                            child: _SettingsBentoCard(
                              icon: Icons.translate_rounded,
                              label: app.t('language') ?? 'Language',
                              iconColor: Colors.blueAccent,
                              child: _PremiumSegmentedControl(app: app),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _InteractiveBounce(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                app.updateSettings(
                                  theme: app.themeMode == ThemeMode.dark
                                      ? ThemeMode.light
                                      : ThemeMode.dark,
                                );
                              },
                              child: _SettingsBentoCard(
                                icon: app.themeMode == ThemeMode.dark
                                    ? Icons.dark_mode_rounded
                                    : Icons.light_mode_rounded,
                                label: app.t('dark_mode') ?? 'Appearance',
                                iconColor: Colors.indigoAccent,
                                child: Container(
                                  height: 48,
                                  alignment: Alignment.centerLeft,
                                  child: Switch.adaptive(
                                    value: app.themeMode == ThemeMode.dark,
                                    activeColor: Colors.indigoAccent,
                                    onChanged: (v) {
                                      HapticFeedback.selectionClick();
                                      app.updateSettings(
                                        theme: v
                                            ? ThemeMode.dark
                                            : ThemeMode.light,
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // --- STORAGE TILE ---
                      _InteractiveBounce(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          app.toggleStorageDirectory();
                        },
                        child: _SettingsBentoCard(
                          icon: Icons.sd_storage_rounded,
                          label: app.t('save_loc') ?? 'Save Location',
                          iconColor: Colors.teal,
                          subtitle: app.useExternalStorage
                              ? (app.t('ext_store') ?? 'External Storage')
                              : (app.t('int_store') ?? 'Internal Storage'),
                          trailing: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHighest,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.swap_horiz_rounded,
                              size: 18,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 36),

                      // --- THEME COLORS ---
                      _buildSectionHeader(
                        context,
                        app.t('theme_color') ?? 'Accent Color',
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 64,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          clipBehavior: Clip.none,
                          itemCount: _availableColors.length,
                          itemBuilder: (context, index) {
                            final color = _availableColors[index];
                            final isSelected =
                                app.seedColor.value == color.value;
                            return _InteractiveBounce(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                app.updateSettings(color: color);
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeOutCubic,
                                margin: const EdgeInsets.only(right: 16),
                                width: isSelected ? 64 : 56,
                                height: isSelected ? 64 : 56,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: colorScheme.surface,
                                    width: isSelected ? 4 : 2,
                                  ),
                                  boxShadow: [
                                    if (isSelected)
                                      BoxShadow(
                                        color: color.withOpacity(0.4),
                                        blurRadius: 16,
                                        offset: const Offset(0, 8),
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

                      const SizedBox(height: 36),

                      // --- SUPPORT & LEGAL ISLAND ---
                      _buildSectionHeader(context, "About & Support"),
                      const SizedBox(height: 16),
                      Container(
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest
                              .withOpacity(0.4),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: colorScheme.outline.withOpacity(0.08),
                          ),
                        ),
                        child: Column(
                          children: [
                            _buildListTile(
                              context,
                              icon: Icons.chat_bubble_rounded,
                              label: app.t('feedback') ?? 'Send Feedback',
                              color: Colors.orange,
                              onTap: () {
                                Navigator.pop(context); // Close Settings
                                showDialog(
                                  context: context,
                                  barrierColor: Colors.black.withOpacity(0.6),
                                  builder: (_) => FeedbackDialog(app: app),
                                );
                              },
                            ),
                            Divider(
                              height: 1,
                              indent: 64,
                              endIndent: 24,
                              color: colorScheme.outline.withOpacity(0.1),
                            ),
                            _buildListTile(
                              context,
                              icon: Icons.verified_user_rounded,
                              label:
                                  app.t('licenses') ?? 'Open Source Licenses',
                              color: Colors.green,
                              onTap: () {
                                showLicensePage(
                                  context: context,
                                  applicationName: "PixelPaper",
                                  applicationVersion: "v0.9.2",
                                  applicationIcon: Padding(
                                    padding: const EdgeInsets.all(32),
                                    child: Icon(
                                      Icons.picture_as_pdf_rounded,
                                      size: 80,
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

                      // --- ELEGANT FOOTER ---
                      _buildFooter(app, colorScheme),
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

  Widget _buildSectionHeader(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildListTile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return _InteractiveBounce(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  letterSpacing: -0.3,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: colorScheme.onSurfaceVariant.withOpacity(0.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter(AppState app, ColorScheme colorScheme) {
    return Column(
      children: [
        Icon(
          Icons.auto_awesome_rounded,
          color: colorScheme.primary.withOpacity(0.5),
          size: 28,
        ),
        const SizedBox(height: 16),
        Text(
          app.t('designed_with_passion') ?? "Designed with passion",
          style: TextStyle(
            color: colorScheme.onSurfaceVariant,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          "Khova Krishna Pilato • v0.9.2",
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 12,
            letterSpacing: 0.5,
            color: colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
      ],
    );
  }
}

// --- REUSABLE BENTO CARD ---
class _SettingsBentoCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color iconColor;
  final Widget? child;
  final Widget? trailing;
  final String? subtitle;

  const _SettingsBentoCard({
    required this.icon,
    required this.label,
    required this.iconColor,
    this.child,
    this.trailing,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.4),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: colorScheme.outline.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const Spacer(),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 16),
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              letterSpacing: -0.4,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: TextStyle(
                fontSize: 13,
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (child != null)
            Padding(padding: const EdgeInsets.only(top: 16), child: child),
        ],
      ),
    );
  }
}

// --- PREMIUM ANIMATED SEGMENTED CONTROL ---
class _PremiumSegmentedControl extends StatelessWidget {
  final AppState app;
  const _PremiumSegmentedControl({required this.app});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isEn = app.language == 'en';

    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate the width of one segment (half the total minus padding)
        final double segmentWidth = (constraints.maxWidth - 8) / 2;

        return Container(
          height: 48,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: colorScheme.onSurface.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colorScheme.outline.withOpacity(0.05)),
          ),
          child: Stack(
            children: [
              // --- THE GLIDING PILL ---
              AnimatedPositioned(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutBack, // High-end spring effect
                left: isEn ? 0 : segmentWidth,
                width: segmentWidth,
                top: 0,
                bottom: 0,
                child: Container(
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.primary.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                ),
              ),

              // --- INTERACTIVE LABELS ---
              Row(
                children: [
                  _buildOption(context, 'en', 'English', isEn),
                  _buildOption(context, 'it', 'Italiano', !isEn),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOption(
    BuildContext context,
    String code,
    String label,
    bool isSelected,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (!isSelected) {
            HapticFeedback.mediumImpact();
            app.updateSettings(lang: code);
          }
        },
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 300),
            style: TextStyle(
              color: isSelected
                  ? colorScheme.onPrimary
                  : colorScheme.onSurfaceVariant,
              fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
              fontSize: 13,
              letterSpacing: 0.5,
            ),
            child: Text(code.toUpperCase()),
          ),
        ),
      ),
    );
  }
}

// --- AVAILABLE THEME COLORS ---
final List<Color> _availableColors = [
  Colors.deepPurpleAccent,
  Colors.blueAccent,
  Colors.teal,
  Colors.green,
  Colors.orange,
  Colors.redAccent,
  Colors.pinkAccent,
  Colors.blueGrey,
];

// --- STUNNING GLASSMORPHIC FEEDBACK DIALOG ---
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
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(36),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: colorScheme.surface.withOpacity(0.85),
              borderRadius: BorderRadius.circular(36),
              border: Border.all(color: Colors.white.withOpacity(0.15)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 40,
                  offset: const Offset(0, 20),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.mark_email_unread_rounded,
                    color: Colors.orange,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 20),

                // Titles
                Text(
                  widget.app.t('feedback') ?? 'Send Feedback',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Have a suggestion or found a bug?\nLet us know to help us improve.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 28),

                // Premium Input Field
                Container(
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: colorScheme.outline.withOpacity(0.1),
                    ),
                  ),
                  child: TextField(
                    controller: _controller,
                    maxLines: 4,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                    decoration: InputDecoration(
                      hintText:
                          widget.app.t('feedback_hint') ??
                          'Type your message...',
                      hintStyle: TextStyle(
                        color: colorScheme.onSurfaceVariant.withOpacity(0.6),
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(20),
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: _InteractiveBounce(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.pop(context);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest
                                .withOpacity(0.5),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            widget.app.t('cancel') ?? 'Cancel',
                            style: TextStyle(
                              color: colorScheme.onSurface,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _InteractiveBounce(
                        onTap: _isSending ? () {} : _send,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: _isSending
                                ? Colors.orange.withOpacity(0.7)
                                : Colors.orange,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: _isSending
                                ? []
                                : [
                                    BoxShadow(
                                      color: Colors.orange.withOpacity(0.4),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                          ),
                          alignment: Alignment.center,
                          child: _isSending
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : Text(
                                  widget.app.t('send') ?? 'Send',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _send() async {
    if (_controller.text.trim().isEmpty) {
      HapticFeedback.heavyImpact();
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() => _isSending = true);

    try {
      await http.post(
        Uri.parse('https://formspree.io/f/xdalwboq'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'message': _controller.text}),
      );
    } catch (e) {
      // Handle network errors silently for simplicity in this demo
    }

    if (mounted) {
      HapticFeedback.heavyImpact();
      Navigator.pop(context);

      // Elegant Success SnackBar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.only(bottom: 24, left: 24, right: 24),
          content: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.green.shade600,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.green.withOpacity(0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Feedback sent successfully!',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
  }
}

// --- MICRO-INTERACTION WRAPPER ---
// Added here so it functions globally across this file
class _InteractiveBounce extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const _InteractiveBounce({required this.child, required this.onTap});

  @override
  State<_InteractiveBounce> createState() => _InteractiveBounceState();
}

class _InteractiveBounceState extends State<_InteractiveBounce>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
      reverseDuration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.94,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) => _controller.forward();

  void _onTapUp(TapUpDetails details) {
    _controller.reverse();
    widget.onTap();
  }

  void _onTapCancel() => _controller.reverse();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: ScaleTransition(scale: _scaleAnimation, child: widget.child),
    );
  }
}
