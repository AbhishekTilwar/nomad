import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nomad_mingle/features/shell/splash_exit.dart';

void main() {
  testWidgets('the splash fades, lifts and grows as it exits', (t) async {
    final c = AnimationController(vsync: const TestVSync(), value: 1);
    final s = AnimationController(vsync: const TestVSync());
    addTearDown(c.dispose);
    addTearDown(s.dispose);
    await t.pumpWidget(
      MaterialApp(
        home: SplashExit(
          animation: c,
          secondaryAnimation: s,
          child: const Text('logo'),
        ),
      ),
    );
    double opacity() => t.widget<Opacity>(find.byType(Opacity)).opacity;
    expect(opacity(), 1);
    c.value = 0.4; // route animating out (replaced)
    await t.pump();
    expect(opacity(), lessThan(1));
    final mid = opacity();
    c.value = 0;
    await t.pump();
    expect(opacity(), lessThan(mid));
    expect(opacity(), 0);
    // Covered by a pushed page instead.
    c.value = 1;
    s.value = 0.5;
    await t.pump();
    expect(opacity(), lessThan(1));
  });
}
