import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pixel_paper/core/widgets/motion.dart';
import 'package:pixel_paper/main.dart';

final _fades = find.descendant(
  of: find.byType(EntranceGroup),
  matching: find.byType(FadeTransition),
);

Widget _app(Widget child, {bool reduced = false}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: reduced),
    child: Scaffold(body: child),
  ),
);

Widget _list(Object epoch, List<int> ids) => EntranceGroup(
  epoch: epoch,
  ids: ids,
  child: Column(
    children: [
      for (var i = 0; i < ids.length; i++)
        Entrance(id: ids[i], index: i, child: Text('item ${ids[i]}')),
    ],
  ),
);

void main() {
  testWidgets('a list cascades in and settles fully visible', (tester) async {
    await tester.pumpWidget(_app(_list(0, [1, 2, 3])));
    expect(_fades, findsNWidgets(3));

    await tester.pumpAndSettle();
    for (final fade in tester.widgetList<FadeTransition>(_fades)) {
      expect(fade.opacity.value, 1);
    }
  });

  testWidgets('reduced motion shows items at once', (tester) async {
    await tester.pumpWidget(_app(_list(0, [1, 2, 3]), reduced: true));
    expect(_fades, findsNothing);
    expect(find.text('item 3'), findsOneWidget);
  });

  testWidgets('a removed item leaves no timer running', (tester) async {
    await tester.pumpWidget(_app(_list(0, List.generate(14, (i) => i))));
    await tester.pump(const Duration(milliseconds: 10));
    await tester.pumpWidget(_app(const SizedBox()));
    // The test framework fails here if a staggered start timer outlived its
    // widget.
  });

  testWidgets('Swapped replaces its label', (tester) async {
    await tester.pumpWidget(
      _app(const Swapped(value: 1, child: Text('1 di 3'))),
    );
    await tester.pumpWidget(
      _app(const Swapped(value: 2, child: Text('2 di 3'))),
    );
    await tester.pumpAndSettle();
    expect(find.text('2 di 3'), findsOneWidget);
    expect(find.text('1 di 3'), findsNothing);
  });

  testWidgets('a widget that fails to build shows a calm card', (tester) async {
    final previous = ErrorWidget.builder;
    ErrorWidget.builder = (details) => ErrorCard(details: details);
    try {
      await tester.pumpWidget(
        MaterialApp(home: Builder(builder: (_) => throw StateError('boom'))),
      );
      expect(tester.takeException(), isStateError);
      expect(find.textContaining('non si è caricata'), findsOneWidget);
    } finally {
      ErrorWidget.builder = previous;
    }
  });
}
