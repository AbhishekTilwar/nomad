import 'package:flutter_test/flutter_test.dart';
import 'package:nomad_mingle/core/utils/plan_emoji.dart';

void main() {
  test('title keywords pick a specific emoji', () {
    expect(PlanEmoji.of('Sunrise chai at Carter Road', 'food'), '☕');
    expect(PlanEmoji.of('Sinhagad sunrise trek', 'hiking'), '🥾');
    expect(PlanEmoji.of('Baner badminton doubles', 'sports'), '🏸');
  });

  test('keywords only match at the start of a word', () {
    expect(PlanEmoji.of('Aundh startup meetup', 'networking'), '🚀');
    expect(PlanEmoji.of('Sunday brunch', 'food'), '🥞');
  });

  test('falls back to the category, then a default', () {
    expect(PlanEmoji.of('Meetup', 'music'), '🎶');
    expect(PlanEmoji.of('Meetup', 'unknown'), '✨');
  });
}
