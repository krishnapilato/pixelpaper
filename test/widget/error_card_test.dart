import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pixel_paper/main.dart';

void main() {
  final details = FlutterErrorDetails(exception: StateError('boom'));

  for (final size in const [
    Size(400, 800),
    Size(400, 56),
    Size(48, 48),
    Size(10, 10),
  ]) {
    testWidgets('fits a ${size.width.toInt()}×${size.height.toInt()} slot', (
      tester,
    ) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: SizedBox.fromSize(
              size: size,
              child: ErrorCard(details: details),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
      expect(
        find.text(ErrorCard.message),
        size.height >= 160 ? findsOneWidget : findsNothing,
      );
    });
  }
}
