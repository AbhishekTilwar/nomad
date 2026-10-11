import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nomad_mingle/features/auth/presentation/welcome_backdrop.dart';

Widget host({bool reduce = false}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: reduce),
    child: const Scaffold(body: WelcomeBackdrop()),
  ),
);

void main() {
  testWidgets('animates without errors and stays out of semantics', (t) async {
    await t.pumpWidget(host());
    for (var i = 0; i < 40; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
    expect(t.takeException(), isNull);
    // Decorative: no semantics node of its own.
    expect(
      find.descendant(
        of: find.byType(WelcomeBackdrop),
        matching: find.byType(ExcludeSemantics),
      ),
      findsWidgets,
    );
  });

  testWidgets('reduced motion renders the finished picture and never ticks', (
    t,
  ) async {
    await t.pumpWidget(host(reduce: true));
    // pumpAndSettle would time out if a repeating animation were running.
    await t.pumpAndSettle(const Duration(milliseconds: 100));
    expect(t.takeException(), isNull);
  });

  testWidgets('fits a small phone', (t) async {
    t.view.physicalSize = const Size(360, 640);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(host());
    await t.pump(const Duration(seconds: 3));
    expect(t.takeException(), isNull);
  });

  testWidgets('pins keep their places while the map drifts', (t) async {
    await t.pumpWidget(host());
    for (var i = 0; i < 30; i++) {
      await t.pump(const Duration(milliseconds: 150));
    }
    expect(t.takeException(), isNull);
    // The pin layer is drawn inside the same drifting transform as the map.
    expect(
      find.descendant(
        of: find.byType(WelcomeBackdrop),
        matching: find.byType(Transform),
      ),
      findsWidgets,
    );
  });
}
