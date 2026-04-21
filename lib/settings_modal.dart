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
  final isDark = Theme.of(context).brightness == Brightness.dark;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    elevation: 0,
    barrierColor: Theme.of(
      context,
    ).colorScheme.shadow.withOpacity(isDark ? 0.5 : 0.3),
    useSafeArea: false,
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
        final size = MediaQuery.sizeOf(context);
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final bottomPadding = MediaQuery.paddingOf(context).bottom;

        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(36)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
            child: Container(
              height: size.height * 0.85, // Standard Pro 85% Height
              width: double.infinity,
              decoration: BoxDecoration(
                color: colorScheme.surface.withOpacity(isDark ? 0.7 : 0.9),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(36),
                ),
                border: Border(
                  top: BorderSide(
                    color: colorScheme.onSurface.withOpacity(0.08),
                    width: 0.5,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Minimalist Drag Handle
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 12, bottom: 20),
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: colorScheme.onSurface.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),

                  // Sticky Pro Header (Clean, No X Button)
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
                            size: 24,
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
                                  fontSize: 24,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.5,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                              Text(
                                app.t('customize_exp') ??
                                    'Customize your experience',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: colorScheme.onSurface.withOpacity(0.5),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Scrollable Content
                  Expanded(
                    child: ListView(
                      physics: const BouncingScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(
                        20,
                        0,
                        20,
                        bottomPadding + 32,
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
                            const SizedBox(width: 12),
                            Expanded(
                              child: _SettingsBentoCard(
                                icon: Icons.palette_rounded,
                                label: app.t('appearance') ?? 'Appearance',
                                child: _ThemeSegmentedControl(app: app),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

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

                        const SizedBox(height: 32),

                        // --- SUPPORT & LEGAL ISLAND ---
                        _buildSectionHeader(context, "About & Support"),
                        const SizedBox(height: 12),
                        Container(
                          decoration: BoxDecoration(
                            color: colorScheme.onSurface.withOpacity(0.03),
                            borderRadius: BorderRadius.circular(24),
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
                                  Navigator.pop(context);
                                  showModalBottomSheet(
                                    context: context,
                                    isScrollControlled: true,
                                    backgroundColor: Colors.transparent,
                                    elevation: 0,
                                    barrierColor: colorScheme.shadow
                                        .withOpacity(isDark ? 0.5 : 0.3),
                                    useSafeArea: false,
                                    builder: (_) => _ProFeedbackSheet(app: app),
                                  );
                                },
                              ),
                              Divider(
                                height: 1,
                                indent: 60,
                                endIndent: 20,
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
                                    applicationVersion: "v1.0.0",
                                    applicationIcon: const Padding(
                                      padding: EdgeInsets.all(32),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 40),

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
      padding: const EdgeInsets.only(left: 8),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
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
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: colorScheme.onSurface.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: colorScheme.onSurface, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
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
          size: 24,
        ),
        const SizedBox(height: 12),
        Text(
          app.t('designed_with_passion') ?? "Designed with passion",
          style: TextStyle(
            color: colorScheme.onSurface.withOpacity(0.5),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          "Khova Krishna Pilato • v1.0.0",
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 11,
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.onSurface.withOpacity(0.03),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorScheme.onSurface.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colorScheme.onSurface.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: colorScheme.onSurface, size: 18),
              ),
              const Spacer(),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 14),
          Text(
            label,
            style: TextStyle(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w700,
              fontSize: 15,
              letterSpacing: -0.3,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurface.withOpacity(0.5),
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (child != null)
            Padding(padding: const EdgeInsets.only(top: 14), child: child),
        ],
      ),
    );
  }
}

// --- APPLE iOS STYLE SEGMENTED CONTROL (LANGUAGE) ---
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
          height: 40,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: colorScheme.onSurface.withOpacity(0.08),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                left: isEn ? 0 : segmentWidth,
                width: segmentWidth,
                top: 0,
                bottom: 0,
                child: Container(
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.3 : 0.1),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
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
            HapticFeedback.selectionClick();
            app.updateSettings(lang: code);
          }
        },
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: TextStyle(
              color: colorScheme.onSurface,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              fontSize: 12,
              letterSpacing: 0.5,
            ),
            child: Text(code.toUpperCase()),
          ),
        ),
      ),
    );
  }
}

// --- UI COHERENT THEME CONTROL (APPEARANCE) ---
class _ThemeSegmentedControl extends StatelessWidget {
  final AppState app;
  const _ThemeSegmentedControl({required this.app});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDarkTarget = app.themeMode == ThemeMode.dark;
    final isDarkModeActive = Theme.of(context).brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final double segmentWidth = (constraints.maxWidth - 8) / 2;

        return Container(
          height: 40,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: colorScheme.onSurface.withOpacity(0.08),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                left: isDarkTarget ? segmentWidth : 0,
                width: segmentWidth,
                top: 0,
                bottom: 0,
                child: Container(
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(
                          isDarkModeActive ? 0.3 : 0.1,
                        ),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                children: [
                  _buildOption(
                    context,
                    Icons.light_mode_rounded,
                    !isDarkTarget,
                    ThemeMode.light,
                  ),
                  _buildOption(
                    context,
                    Icons.dark_mode_rounded,
                    isDarkTarget,
                    ThemeMode.dark,
                  ),
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
    IconData icon,
    bool isSelected,
    ThemeMode mode,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (!isSelected) {
            HapticFeedback.selectionClick();
            app.updateSettings(theme: mode);
          }
        },
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            child: Icon(
              icon,
              size: 18,
              color: isSelected
                  ? colorScheme.onSurface
                  : colorScheme.onSurface.withOpacity(0.4),
            ),
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// STUNNING GLASSMORPHIC FEEDBACK SHEET (COHERENT WITH SETTINGS)
// -----------------------------------------------------------------------------
class _ProFeedbackSheet extends StatefulWidget {
  final AppState app;
  const _ProFeedbackSheet({required this.app});

  @override
  State<_ProFeedbackSheet> createState() => _ProFeedbackSheetState();
}

class _ProFeedbackSheetState extends State<_ProFeedbackSheet> {
  final TextEditingController _controller = TextEditingController();
  bool _isSending = false;
  bool _isBugReport = false;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final isNotEmpty = _controller.text.trim().isNotEmpty;
      if (_hasText != isNotEmpty) {
        setState(() => _hasText = isNotEmpty);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _showProToast(
    BuildContext context,
    ScaffoldMessengerState messenger,
    String message,
    IconData icon,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    messenger.showSnackBar(
      SnackBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(
          bottom: bottomPadding + 24,
          left: 24,
          right: 24,
        ),
        padding: EdgeInsets.zero,
        content: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: colorScheme.onSurface.withOpacity(isDark ? 0.9 : 0.85),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: colorScheme.surface, size: 20),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      message,
                      style: TextStyle(
                        color: colorScheme.surface,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
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
    if (!_hasText) return;

    HapticFeedback.mediumImpact();
    setState(() => _isSending = true);

    try {
      await http.post(
        Uri.parse('https://formspree.io/f/xdalwboq'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'type': _isBugReport ? 'Bug Report' : 'Feedback',
          'message': _controller.text,
        }),
      );
    } catch (e) {
      // Handle network errors silently for smooth UX flow
    }

    if (mounted) {
      HapticFeedback.heavyImpact();
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      _showProToast(
        context,
        messenger,
        widget.app.t('feedback_sent') ?? 'Feedback sent successfully!',
        Icons.check_circle_rounded,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final viewInsets = MediaQuery.viewInsetsOf(context);
    final size = MediaQuery.sizeOf(context);

    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(36)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
          child: Container(
            decoration: BoxDecoration(
              color: colorScheme.surface.withOpacity(isDark ? 0.7 : 0.9),
              border: Border(
                top: BorderSide(
                  color: colorScheme.onSurface.withOpacity(0.08),
                  width: 0.5,
                ),
              ),
            ),
            constraints: BoxConstraints(maxHeight: size.height * 0.85),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Minimal Drag Indicator
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 24),
                      decoration: BoxDecoration(
                        color: colorScheme.onSurface.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // Header (No X button, aligned like Settings)
                  Text(
                    widget.app.t('feedback') ?? 'Submit Feedback',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Type Selector
                  Row(
                    children: [
                      Expanded(
                        child: _FeedbackTypeChip(
                          icon: Icons.lightbulb_outline_rounded,
                          label: "Suggestion",
                          isSelected: !_isBugReport,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _isBugReport = false);
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _FeedbackTypeChip(
                          icon: Icons.bug_report_outlined,
                          label: "Bug Report",
                          isSelected: _isBugReport,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _isBugReport = true);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Apple-style Frosted Input Box
                  Container(
                    decoration: BoxDecoration(
                      color: colorScheme.onSurface.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: colorScheme.onSurface.withOpacity(0.08),
                      ),
                    ),
                    child: TextField(
                      controller: _controller,
                      maxLines: 4,
                      minLines: 3,
                      textInputAction: TextInputAction.newline,
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: colorScheme.onSurface,
                        fontSize: 15,
                      ),
                      decoration: InputDecoration(
                        hintText:
                            widget.app.t('feedback_hint') ??
                            'Describe what happened or what you\'d like to see...',
                        hintStyle: TextStyle(
                          color: colorScheme.onSurface.withOpacity(0.4),
                          fontSize: 14,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.all(16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Send Button
                  ProFluidBounce(
                    onTap: (_isSending || !_hasText) ? () {} : _send,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: _hasText
                            ? colorScheme.onSurface
                            : colorScheme.onSurface.withOpacity(
                                0.15,
                              ), // Disabled visually
                        borderRadius: BorderRadius.circular(16),
                      ),
                      alignment: Alignment.center,
                      child: _isSending
                          ? SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                color: colorScheme.surface,
                                strokeWidth: 2.5,
                              ),
                            )
                          : Text(
                              widget.app.t('send') ?? 'Send to Developer',
                              style: TextStyle(
                                color: _hasText
                                    ? colorScheme.surface
                                    : colorScheme.onSurface.withOpacity(0.4),
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
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
}

// --- FEEDBACK TYPE CHIP ---
class _FeedbackTypeChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FeedbackTypeChip({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ProFluidBounce(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.onSurface
              : colorScheme.onSurface.withOpacity(0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? Colors.transparent
                : colorScheme.onSurface.withOpacity(0.08),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected
                  ? colorScheme.surface
                  : colorScheme.onSurface.withOpacity(0.5),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? colorScheme.surface
                    : colorScheme.onSurface.withOpacity(0.6),
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
