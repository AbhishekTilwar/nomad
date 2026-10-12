import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nomad_mingle/core/widgets/brand_mark.dart';

Widget _host(Widget w) => MaterialApp(
  home: Scaffold(body: Center(child: w)),
);

void main() {
  const pin = ValueKey('brand-mark-image');
  const name = ValueKey('brand-mark-name');
  const tag = ValueKey('brand-mark-tagline');

  testWidgets('at rest only the name and tagline show, no pin', (t) async {
    await t.pumpWidget(_host(const BrandMark(width: 260)));
    await t.pump();
    expect(find.byKey(pin), findsNothing);
    expect(find.byKey(name), findsOneWidget);
    expect(find.text(BrandMark.tagline), findsOneWidget);
    expect(
      t.getTopLeft(find.byKey(name)).dy,
      lessThan(t.getTopLeft(find.byKey(tag)).dy),
    );
  });

  testWidgets('the splash drops the pin in, then it exits', (t) async {
    await t.pumpWidget(_host(const BrandMark(width: 260, animate: true)));
    await t.pump(const Duration(milliseconds: 500));
    expect(find.byKey(pin), findsOneWidget); // pin is on screen early on
    await t.pump(const Duration(milliseconds: 3000));
    expect(find.byKey(pin), findsNothing); // gone once the exit finishes
    expect(find.byKey(name), findsOneWidget);
    final tagOpacity = t.widget<Opacity>(
      find.ancestor(of: find.byKey(tag), matching: find.byType(Opacity)).first,
    );
    expect(tagOpacity.opacity, 1);
  });

  testWidgets('the name ends where the resting layout puts it', (t) async {
    await t.pumpWidget(_host(const BrandMark(width: 260)));
    await t.pump();
    final rest = t.getTopLeft(find.byKey(name));
    await t.pumpWidget(_host(const BrandMark(width: 260, animate: true)));
    await t.pump(const Duration(milliseconds: 3500));
    expect(t.getTopLeft(find.byKey(name)), rest);
  });
}
