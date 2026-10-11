import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nomad_mingle/features/activities/data/activity_repository.dart';
import 'package:nomad_mingle/features/activities/models/activity.dart';
import 'package:nomad_mingle/features/activities/presentation/activity_detail_screen.dart';
import 'package:nomad_mingle/features/discover/presentation/discover_controller.dart'
    show DateFilter;
import 'package:nomad_mingle/features/explore/presentation/explore_controller.dart';
import 'package:provider/provider.dart';

import '../support/fakes.dart';

Future<void> pumpDetail(WidgetTester t, Activity a) async {
  t.view.physicalSize = const Size(800, 2400);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    Provider<ActivityRepository>.value(
      value: FakeActivityRepository([a]),
      child: const MaterialApp(home: ActivityDetailScreen(activityId: 'a1')),
    ),
  );
  for (var i = 0; i < 10; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('open plan: states what to expect and spots left honestly', (
    t,
  ) async {
    await pumpDetail(t, sampleActivity(capacity: 6, participants: 2));
    expect(find.text('What to expect'), findsOneWidget);
    expect(find.text('2 going · 4 spots left'), findsOneWidget);
    expect(find.textContaining('No approval needed'), findsOneWidget);
    expect(find.text('Free to join.'), findsOneWidget);
    expect(find.text('Join'), findsOneWidget);
    expect(find.text('Open group chat'), findsNothing);
  });

  testWidgets('approval plan explains the host reviews requests', (t) async {
    await pumpDetail(t, sampleActivity(approvalRequired: true));
    expect(find.textContaining('host reviews each request'), findsOneWidget);
    expect(find.text('Request to join'), findsOneWidget);
  });

  testWidgets('requested: tells the user what happens next', (t) async {
    await pumpDetail(
      t,
      sampleActivity(
        approvalRequired: true,
        membership: MembershipStatus.requested,
      ),
    );
    expect(find.textContaining('reply under the bell'), findsOneWidget);
  });

  testWidgets('joined: group chat is the primary next step', (t) async {
    await pumpDetail(t, sampleActivity(membership: MembershipStatus.approved));
    expect(find.text('Open group chat'), findsOneWidget);
    expect(find.text('Leave'), findsOneWidget);
    expect(find.text('You\'re going'), findsOneWidget);
    expect(find.text('Get directions'), findsWidgets);
  });

  testWidgets('full plan reads as full, not as a bare fraction', (t) async {
    await pumpDetail(t, sampleActivity(capacity: 2, participants: 2));
    expect(find.text('2 going · full'), findsOneWidget);
    expect(find.text('Full'), findsOneWidget);
  });

  testWidgets('directions and share are reachable', (t) async {
    await pumpDetail(t, sampleActivity());
    await t.scrollUntilVisible(
      find.text('Get directions'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Get directions'), findsOneWidget);
    await t.tap(find.byTooltip('More'));
    await t.pumpAndSettle();
    expect(find.text('Share plan'), findsOneWidget);
  });

  test('clearFilters resets category, price and date filters', () async {
    final c = ExploreController(
      FakeActivityRepository([sampleActivity()]),
      initialCity: 'mumbai',
    );
    c.toggleCategory('food');
    c.setFreeOnly(true);
    c.dateFilter = DateFilter.today;
    expect(c.hasActiveFilters, isTrue);
    c.clearFilters();
    expect(c.hasActiveFilters, isFalse);
    c.dispose();
  });
}
