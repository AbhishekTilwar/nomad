import 'package:flutter_test/flutter_test.dart';
import 'package:nomad_mingle/core/widgets/plan_pin.dart';
import 'package:nomad_mingle/features/activities/models/activity.dart';

void main() {
  group('planTimeLabel', () {
    final now = DateTime(2026, 10, 12, 15, 0);
    test('starting or started', () {
      expect(planTimeLabel(now, now), 'now');
      expect(planTimeLabel(now.subtract(const Duration(minutes: 5)), now), 'now');
    });
    test('soon uses relative time', () {
      expect(planTimeLabel(now.add(const Duration(minutes: 40)), now), 'in 40m');
      expect(planTimeLabel(now.add(const Duration(hours: 3)), now), 'in 3h');
    });
    test('later today shows the clock, then Tmrw, then weekday', () {
      expect(planTimeLabel(DateTime(2026, 10, 12, 21, 30), now), '9:30 PM');
      expect(planTimeLabel(DateTime(2026, 10, 13, 9), now), 'Tmrw');
      expect(planTimeLabel(DateTime(2026, 10, 17, 9), now), 'Sat');
    });
  });

  test('slim map payload derives capacity from going + spots left', () {
    final a = Activity.fromJson({
      'id': 'a1',
      'title': 'Jam',
      'category': 'music',
      'latitude': 18.5,
      'longitude': 73.9,
      'startAt': '2026-10-13T12:00:00.000Z',
      'spotsLeft': 8,
      'participantCount': 7,
      'costType': 'free',
    });
    expect(a.capacity, 15);
    expect(a.participantCount, 7);
    expect(a.isFull, isFalse);
  });
}
