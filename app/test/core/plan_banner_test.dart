import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nomad_mingle/core/widgets/plan_banner.dart';

void main() {
  test('scene follows the title first, then the category', () {
    expect(PlanScene.of('Sunrise trek to Sinhagad', 'hiking'), PlanScene.trek);
    expect(PlanScene.of('Sunday chai walk', 'outings'), PlanScene.coffee);
    expect(PlanScene.of('Open mic night', 'music'), PlanScene.music);
    expect(PlanScene.of('Aundh startup meetup', 'networking'), PlanScene.network);
    expect(PlanScene.of('Meetup', 'food'), PlanScene.food);
    expect(PlanScene.of('Meetup', 'nonsense'), PlanScene.explore);
  });

  test('keywords match at a word start ("art" is not in "startup")', () {
    expect(PlanScene.of('Startup chai', 'networking'), isNot(PlanScene.art));
  });

  testWidgets('every scene paints without errors in any shape', (t) async {
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              for (final s in PlanScene.values) ...[
                SizedBox(
                  width: 80,
                  height: 80,
                  child: ClipOval(child: CustomPaint(painter: PlanScenePainter(s))),
                ),
                SizedBox(
                  width: 300,
                  height: 90,
                  child: CustomPaint(painter: PlanScenePainter(s)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
    expect(tester(t), isNull);
  });

  testWidgets('PlanBanner draws the scene when there is no cover', (t) async {
    await t.pumpWidget(
      const MaterialApp(
        home: SizedBox(
          width: 200,
          height: 100,
          child: PlanBanner(title: 'Sunrise trek', category: 'hiking'),
        ),
      ),
    );
    expect(find.byType(CustomPaint), findsWidgets);
  });
}

Object? tester(WidgetTester t) => t.takeException();
