import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nomad_mingle/core/widgets/brand_logo.dart';
import 'package:nomad_mingle/features/auth/presentation/scenes/hero_scene.dart';

void main() {
  for (final kind in HeroSceneKind.values) {
    testWidgets('HeroScene ${kind.name} paints at several sizes', (t) async {
      t.view.physicalSize = const Size(1000, 800);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      for (final size in const [
        Size(360, 640),
        Size(360, 380),
        Size(900, 500),
      ]) {
        await t.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: size.width,
                height: size.height,
                child: HeroScene(kind: kind),
              ),
            ),
          ),
        );
        expect(t.takeException(), isNull);
        expect(t.getSize(find.byType(HeroScene)), size);
      }
      expect(find.byType(ExcludeSemantics), findsWidgets);
    });
  }

  testWidgets('BrandLogo renders wordmark with a single semantic label', (
    t,
  ) async {
    final handle = t.ensureSemantics();
    await t.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: BrandLogo())),
      ),
    );
    expect(find.bySemanticsLabel('Nomad Mingle'), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);
    handle.dispose();
  });
}
