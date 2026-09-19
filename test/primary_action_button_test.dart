import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixel_paper/features/gallery/presentation/gallery_screen.dart'
    show selectionOrder;
import 'package:pixel_paper/features/shell/presentation/primary_action_button.dart';

class _Calls {
  int scan = 0;
  int camera = 0;
  int import = 0;
  int early = 0;
}

Future<_Calls> _pump(WidgetTester tester, {required double page}) async {
  final calls = _Calls();
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: PrimaryActionButton(
            page: AlwaysStoppedAnimation(page),
            scanLabel: 'Scansiona',
            cameraLabel: 'Fotocamera',
            importLabel: 'Importa',
            holdHint: 'Tieni premuto',
            onScan: () => calls.scan++,
            onCamera: () => calls.camera++,
            onImport: () => calls.import++,
            onHoldReleasedEarly: () => calls.early++,
            onHoldChanged: (_) {},
          ),
        ),
      ),
    ),
  );
  return calls;
}

void main() {
  testWidgets('a tap in the Galleria opens the camera', (tester) async {
    final calls = await _pump(tester, page: 1);
    await tester.tap(find.byType(PrimaryActionButton));
    await tester.pumpAndSettle();
    expect(calls.camera, 1);
    expect(calls.import, 0);
  });

  testWidgets('holding for two seconds opens the import', (tester) async {
    final calls = await _pump(tester, page: 1);
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(PrimaryActionButton)),
    );
    // The hold's clock starts on the first frame after the press.
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(seconds: 1));
    expect(calls.import, 0);
    await tester.pump(const Duration(milliseconds: 1100));
    expect(calls.import, 1);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(calls.import, 1);
    expect(calls.camera, 0);
  });

  testWidgets('letting go early imports nothing and explains', (tester) async {
    final calls = await _pump(tester, page: 1);
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(PrimaryActionButton)),
    );
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 900));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(calls.import, 0);
    expect(calls.camera, 0);
    expect(calls.early, 1);
  });

  testWidgets('in the Archivio the button scans', (tester) async {
    final calls = await _pump(tester, page: 0);
    await tester.tap(find.byType(PrimaryActionButton));
    await tester.pumpAndSettle();
    expect(calls.scan, 1);
    expect(calls.camera, 0);
  });

  test('album pages follow the order the photos were picked in', () {
    final picked = <int>{42, 7, 19};
    expect(selectionOrder(picked, 42), 1);
    expect(selectionOrder(picked, 7), 2);
    expect(selectionOrder(picked, 19), 3);
    expect(selectionOrder(picked, 5), isNull);
  });
}
