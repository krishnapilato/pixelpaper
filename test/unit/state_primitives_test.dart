import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixel_paper/core/state/selection_controller.dart';
import 'package:pixel_paper/core/state/serial.dart';

final _selection = NotifierProvider<SelectionController, Set<int>>(
  SelectionController.new,
);

void main() {
  group('Serial', () {
    test('runs tasks one at a time, in call order', () async {
      final serial = Serial();
      final log = <String>[];
      final slow = Completer<void>();

      final first = serial.run(() async {
        log.add('first start');
        await slow.future;
        log.add('first end');
      });
      final second = serial.run(() async => log.add('second'));

      await Future<void>.delayed(Duration.zero);
      expect(log, ['first start']);
      expect(serial.isBusy, isTrue);

      slow.complete();
      await Future.wait([first, second]);
      expect(log, ['first start', 'first end', 'second']);
      expect(serial.isBusy, isFalse);
    });

    test('a failure reaches its caller and does not block the queue', () async {
      final serial = Serial();
      final failing = serial.run<void>(() async => throw StateError('boom'));
      final next = serial.run(() async => 42);

      await expectLater(failing, throwsStateError);
      expect(await next, 42);
    });
  });

  group('SelectionController', () {
    late ProviderContainer container;
    setUp(() => container = ProviderContainer());
    tearDown(() => container.dispose());

    SelectionController notifier() => container.read(_selection.notifier);
    Set<int> state() => container.read(_selection);

    test('toggles, selects all and clears', () {
      notifier()
        ..toggle(1)
        ..toggle(2)
        ..toggle(1);
      expect(state(), {2});
      notifier().selectAll([3, 4]);
      expect(state(), {3, 4});
      notifier().clear();
      expect(state(), isEmpty);
    });

    test('drops ids that disappeared', () {
      notifier().selectAll([1, 2, 3]);
      notifier().retain({2, 3, 9});
      expect(state(), {2, 3});
    });

    test('state cannot be mutated from outside', () {
      notifier().selectAll([1]);
      expect(() => state().add(5), throwsUnsupportedError);
    });

    test('an unchanged selection notifies nobody', () {
      var notified = 0;
      notifier().selectAll([1, 2]);
      container.listen(_selection, (_, _) => notified++);
      notifier()
        ..retain({1, 2, 3})
        ..clear()
        ..clear();
      expect(notified, 1);
    });
  });
}
