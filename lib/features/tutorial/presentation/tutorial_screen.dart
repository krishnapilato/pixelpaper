import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/strings.dart';
import '../../../core/theme/dimens.dart';
import 'widgets/tutorial_illustrations.dart';

/// The in-app guide, reachable from Impostazioni.
///
/// Seven steps, one idea each, with drawn placeholders instead of screenshots —
/// screenshots go stale the moment the UI changes, and localised screenshots
/// go stale twice as fast.
///
/// Every step carries three concrete tips under the explanation: the paragraph
/// says what the feature is for, the tips say which finger does what. A guide
/// that only describes leaves the reader exactly where they started.
class TutorialScreen extends ConsumerStatefulWidget {
  const TutorialScreen({super.key});

  @override
  ConsumerState<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends ConsumerState<TutorialScreen> {
  final _controller = PageController();
  int _index = 0;

  static const List<({String key, Widget art})> _steps = [
    (key: 'tutorial_1', art: ScanIllustration()),
    (key: 'tutorial_2', art: NamingIllustration()),
    (key: 'tutorial_3', art: GalleryIllustration()),
    (key: 'tutorial_4', art: EditorIllustration()),
    (key: 'tutorial_5', art: FoldersIllustration()),
    (key: 'tutorial_6', art: TextIllustration()),
    (key: 'tutorial_7', art: ShareIllustration()),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_index >= _steps.length - 1) {
      Navigator.of(context).pop();
      return;
    }
    // Slow on purpose: a page turn the eye can follow. The guide never
    // advances on its own — it moves only when the reader asks it to.
    _controller.nextPage(duration: Motion.slow, curve: Motion.emphasized);
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(stringsProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isLast = _index == _steps.length - 1;

    return Scaffold(
      appBar: AppBar(
        title: Text(strings('tutorial_title')),
        actions: [
          if (!isLast)
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(strings('tutorial_skip')),
            ),
          const SizedBox(width: Space.xs),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _controller,
              itemCount: _steps.length,
              onPageChanged: (index) => setState(() => _index = index),
              itemBuilder: (context, index) {
                final step = _steps[index];
                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Space.page,
                    vertical: Space.md,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Card(
                        color: scheme.surfaceContainer,
                        child: Padding(
                          padding: const EdgeInsets.all(Space.md),
                          child: Column(
                            children: [
                              step.art,
                              const SizedBox(height: Space.sm),
                              Text(
                                strings('${step.key}_caption'),
                                textAlign: TextAlign.center,
                                style: theme.textTheme.labelSmall,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: Space.lg),
                      Text(
                        strings('tutorial_step', {
                          'a': index + 1,
                          'b': _steps.length,
                        }),
                        style: theme.textTheme.labelSmall,
                      ),
                      const SizedBox(height: Space.xs),
                      Text(
                        strings('${step.key}_title'),
                        style: theme.textTheme.headlineMedium,
                      ),
                      const SizedBox(height: Space.sm),
                      Text(
                        strings('${step.key}_body'),
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: Space.md),
                      for (var tip = 1; tip <= 3; tip++)
                        _Tip(text: strings('${step.key}_tip_$tip')),
                    ],
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              Space.page,
              Space.sm,
              Space.page,
              MediaQuery.paddingOf(context).bottom + Space.md,
            ),
            child: Row(
              children: [
                for (var i = 0; i < _steps.length; i++)
                  AnimatedContainer(
                    duration: Motion.quick,
                    margin: const EdgeInsets.only(right: 6),
                    height: 6,
                    width: i == _index ? 22 : 6,
                    decoration: BoxDecoration(
                      color: i == _index
                          ? scheme.primary
                          : scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                const Spacer(),
                FilledButton(
                  onPressed: _next,
                  child: Text(
                    isLast
                        ? strings('tutorial_done')
                        : strings('tutorial_next'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One practical line under a step: what to actually do with your finger.
class _Tip extends StatelessWidget {
  const _Tip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: Space.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Icon(Icons.check_rounded, size: 16, color: scheme.primary),
          ),
          const SizedBox(width: Space.sm),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
