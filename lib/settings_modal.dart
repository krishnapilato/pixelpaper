import 'dart:io';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'app_state.dart';

// -----------------------------------------------------------------------------
// PRO FLUID BOUNCE (Apple-style spring physics)
// -----------------------------------------------------------------------------
class ProFluidBounce extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final double scaleEnd;

  const ProFluidBounce({
    super.key,
    required this.child,
    required this.onTap,
    this.onLongPress,
    this.scaleEnd = 0.95,
  });

  @override
  State<ProFluidBounce> createState() => _ProFluidBounceState();
}

class _ProFluidBounceState extends State<ProFluidBounce>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
      reverseDuration: const Duration(milliseconds: 300),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: widget.scaleEnd).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeOutBack,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      onLongPress: widget.onLongPress != null
          ? () {
              HapticFeedback.heavyImpact();
              widget.onLongPress!();
            }
          : null,
      child: ScaleTransition(scale: _scaleAnimation, child: widget.child),
    );
  }
}

// -----------------------------------------------------------------------------
// SETTINGS MODAL INITIATOR
// -----------------------------------------------------------------------------
void showSettingsModal(BuildContext context, AppState app) {
  HapticFeedback.mediumImpact();
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    elevation: 0,
    barrierColor: Theme.of(context).colorScheme.shadow.withOpacity(0.3),
    useSafeArea: true,
    builder: (context) => const _StudioSettingsSheet(),
  );
}

// -----------------------------------------------------------------------------
// MAIN SETTINGS SHEET
// -----------------------------------------------------------------------------
class _StudioSettingsSheet extends StatelessWidget {
  const _StudioSettingsSheet();

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, app, child) {
        final colorScheme = Theme.of(context).colorScheme;
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final bottomPadding = MediaQuery.of(context).padding.bottom;

        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
            child: Container(
              height: MediaQuery.of(context).size.height * 0.88,
              decoration: BoxDecoration(
                color: colorScheme.surface.withOpacity(isDark ? 0.6 : 0.85),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(40),
                ),
                border: Border(
                  top: BorderSide(
                    color: colorScheme.onSurface.withOpacity(0.08),
                    width: 0.5,
                  ),
                ),
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
                        color: colorScheme.onSurface.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),

                  // Sticky Pro Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: colorScheme.onSurface.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            Icons.tune_rounded,
                            color: colorScheme.onSurface,
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
                                  fontSize: 26,
                                  fontWeight: FontWeight.w700,
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
                                  color: colorScheme.onSurface.withOpacity(0.5),
                                ),
                              ),
                            ],
                          ),
                        ),
                        ProFluidBounce(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            Navigator.pop(context);
                          },
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: colorScheme.onSurface.withOpacity(0.05),
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
                      padding: EdgeInsets.fromLTRB(
                        24,
                        0,
                        24,
                        bottomPadding + 40,
                      ),
                      children: [
                        // --- PRO BENTO GRID ---
                        Row(
                          children: [
                            Expanded(
                              child: _SettingsBentoCard(
                                icon: Icons.translate_rounded,
                                label: app.t('language') ?? 'Language',
                                child: _PremiumSegmentedControl(app: app),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: ProFluidBounce(
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
                                  child: Container(
                                    height: 48,
                                    alignment: Alignment.centerLeft,
                                    child: Switch.adaptive(
                                      value: app.themeMode == ThemeMode.dark,
                                      activeColor: colorScheme.onSurface,
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
                        ProFluidBounce(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            app.toggleStorageDirectory();
                          },
                          child: _SettingsBentoCard(
                            icon: Icons.sd_storage_rounded,
                            label: app.t('save_loc') ?? 'Save Location',
                            subtitle: app.useExternalStorage
                                ? (app.t('ext_store') ?? 'External Storage')
                                : (app.t('int_store') ?? 'Internal Storage'),
                            trailing: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: colorScheme.onSurface.withOpacity(0.05),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.swap_horiz_rounded,
                                size: 18,
                                color: colorScheme.onSurface,
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
                              return ProFluidBounce(
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
                                      width: isSelected ? 4 : 0,
                                    ),
                                    boxShadow: isSelected
                                        ? [
                                            BoxShadow(
                                              color: color.withOpacity(0.4),
                                              blurRadius: 16,
                                              offset: const Offset(0, 8),
                                            ),
                                          ]
                                        : [],
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
                            color: colorScheme.onSurface.withOpacity(0.03),
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(
                              color: colorScheme.onSurface.withOpacity(0.05),
                            ),
                          ),
                          child: Column(
                            children: [
                              _buildListTile(
                                context,
                                icon: Icons.chat_bubble_rounded,
                                label: app.t('feedback') ?? 'Send Feedback',
                                onTap: () {
                                  Navigator.pop(context); // Close Settings
                                  showDialog(
                                    context: context,
                                    barrierColor: Colors.black.withOpacity(0.4),
                                    builder: (_) => FeedbackDialog(app: app),
                                  );
                                },
                              ),
                              Divider(
                                height: 1,
                                indent: 64,
                                endIndent: 24,
                                color: colorScheme.onSurface.withOpacity(0.05),
                              ),
                              _buildListTile(
                                context,
                                icon: Icons.verified_user_rounded,
                                label:
                                    app.t('licenses') ?? 'Open Source Licenses',
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
                                        color: colorScheme.onSurface,
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
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildListTile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return ProFluidBounce(
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
                color: colorScheme.onSurface.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: colorScheme.onSurface, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  letterSpacing: -0.2,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: colorScheme.onSurface.withOpacity(0.3),
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
          color: colorScheme.onSurface.withOpacity(0.2),
          size: 28,
        ),
        const SizedBox(height: 16),
        Text(
          app.t('designed_with_passion') ?? "Designed with passion",
          style: TextStyle(
            color: colorScheme.onSurface.withOpacity(0.5),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          "Khova Krishna Pilato • v0.9.2",
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 12,
            letterSpacing: 0.5,
            color: colorScheme.onSurface.withOpacity(0.4),
          ),
        ),
      ],
    );
  }
}

// --- REUSABLE PRO BENTO CARD ---
class _SettingsBentoCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget? child;
  final Widget? trailing;
  final String? subtitle;

  const _SettingsBentoCard({
    required this.icon,
    required this.label,
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
        color: colorScheme.onSurface.withOpacity(0.03),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: colorScheme.onSurface.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colorScheme.onSurface.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: colorScheme.onSurface, size: 20),
              ),
              const Spacer(),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 16),
          Text(
            label,
            style: TextStyle(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w700,
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
                color: colorScheme.onSurface.withOpacity(0.5),
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

// --- APPLE iOS STYLE SEGMENTED CONTROL ---
class _PremiumSegmentedControl extends StatelessWidget {
  final AppState app;
  const _PremiumSegmentedControl({required this.app});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isEn = app.language == 'en';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final double segmentWidth = (constraints.maxWidth - 8) / 2;

        return Container(
          height: 44,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: colorScheme.onSurface.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOutBack,
                left: isEn ? 0 : segmentWidth,
                width: segmentWidth,
                top: 0,
                bottom: 0,
                child: Container(
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.3 : 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                children: [
                  _buildOption(context, 'en', isEn),
                  _buildOption(context, 'it', !isEn),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOption(BuildContext context, String code, bool isSelected) {
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
              color: colorScheme.onSurface,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
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

  void _showProToast(BuildContext context, String message, IconData icon) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(top: 50, left: 24, right: 24),
        padding: EdgeInsets.zero,
        content: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: colorScheme.onSurface.withOpacity(isDark ? 0.9 : 0.8),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: colorScheme.surface, size: 20),
                  const SizedBox(width: 12),
                  Text(
                    message,
                    style: TextStyle(
                      color: colorScheme.surface,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
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
      // Handle network errors silently
    }

    if (mounted) {
      HapticFeedback.heavyImpact();
      Navigator.pop(context);
      _showProToast(
        context,
        'Feedback sent successfully!',
        Icons.check_circle_rounded,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(40),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: colorScheme.surface.withOpacity(isDark ? 0.6 : 0.85),
              borderRadius: BorderRadius.circular(40),
              border: Border.all(
                color: colorScheme.onSurface.withOpacity(0.08),
              ),
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
                Icon(
                  Icons.mark_email_unread_rounded,
                  color: colorScheme.onSurface,
                  size: 48,
                ),
                const SizedBox(height: 20),

                Text(
                  widget.app.t('feedback') ?? 'Send Feedback',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
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
                    color: colorScheme.onSurface.withOpacity(0.5),
                  ),
                ),
                const SizedBox(height: 28),

                Container(
                  decoration: BoxDecoration(
                    color: colorScheme.onSurface.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: colorScheme.onSurface.withOpacity(0.08),
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
                        color: colorScheme.onSurface.withOpacity(0.4),
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(20),
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                Row(
                  children: [
                    Expanded(
                      child: ProFluidBounce(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.pop(context);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: colorScheme.onSurface.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            widget.app.t('cancel') ?? 'Cancel',
                            style: TextStyle(
                              color: colorScheme.onSurface,
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ProFluidBounce(
                        onTap: _isSending ? () {} : _send,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: colorScheme.onSurface,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          alignment: Alignment.center,
                          child: _isSending
                              ? SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    color: colorScheme.surface,
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : Text(
                                  widget.app.t('send') ?? 'Send',
                                  style: TextStyle(
                                    color: colorScheme.surface,
                                    fontWeight: FontWeight.w700,
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
}
