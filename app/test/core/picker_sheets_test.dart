import 'package:flutter/cupertino.dart' show CupertinoDatePickerMode;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nomad_mingle/core/theme/app_theme.dart';
import 'package:nomad_mingle/core/widgets/picker_sheets.dart';

Future<void> host(
  WidgetTester t,
  Future<void> Function(BuildContext) onTap,
) async {
  t.view.physicalSize = const Size(800, 1800);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Builder(
        builder: (c) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => onTap(c),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await t.tap(find.text('open'));
  await t.pumpAndSettle();
}

void main() {
  testWidgets('option sheet returns the tapped value and marks the current', (
    t,
  ) async {
    int? got;
    await host(t, (c) async {
      got = await showOptionSheet<int>(
        c,
        title: 'How long?',
        selected: 120,
        options: const [
          PickerOption(60, '1 hour'),
          PickerOption(120, '2 hours'),
        ],
      );
    });
    expect(find.text('How long?'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    await t.tap(find.text('1 hour'));
    await t.pumpAndSettle();
    expect(got, 60);
  });

  testWidgets('searchable option sheet filters long lists', (t) async {
    String? got;
    await host(t, (c) async {
      got = await showOptionSheet<String>(
        c,
        title: 'Country',
        searchable: true,
        options: const [
          PickerOption('IN', 'India'),
          PickerOption('IT', 'Italy'),
          PickerOption('JP', 'Japan'),
        ],
      );
    });
    await t.enterText(find.byType(TextField), 'ita');
    await t.pumpAndSettle();
    expect(find.text('India'), findsNothing);
    expect(find.text('Italy'), findsOneWidget);
    await t.tap(find.text('Italy'));
    await t.pumpAndSettle();
    expect(got, 'IT');
  });

  testWidgets('searchable sheet says so when nothing matches', (t) async {
    await host(t, (c) async {
      await showOptionSheet<String>(
        c,
        title: 'Country',
        searchable: true,
        options: const [PickerOption('IN', 'India')],
      );
    });
    await t.enterText(find.byType(TextField), 'zzz');
    await t.pumpAndSettle();
    expect(find.text('No matches.'), findsOneWidget);
  });

  testWidgets('date sheet shows a live summary and confirms the value', (
    t,
  ) async {
    DateTime? got;
    final initial = DateTime(2000, 6, 15);
    await host(t, (c) async {
      got = await showDateWheelSheet(
        c,
        title: 'Your birthday',
        helper: 'No changes later.',
        initial: initial,
        min: DateTime(1920),
        max: DateTime(2030),
        confirmLabel: 'Confirm birthday',
        summary: (d) => 'Year ${d.year}',
      );
    });
    expect(find.text('Your birthday'), findsOneWidget);
    expect(find.text('No changes later.'), findsOneWidget);
    expect(find.text('Year 2000'), findsOneWidget);
    await t.tap(find.text('Confirm birthday'));
    await t.pumpAndSettle();
    expect(got, initial);
  });

  testWidgets('a rejected value shows the error and disables confirm', (
    t,
  ) async {
    DateTime? got;
    await host(t, (c) async {
      got = await showDateWheelSheet(
        c,
        title: 'Start',
        mode: CupertinoDatePickerMode.date,
        initial: DateTime(2000, 1, 1),
        min: DateTime(1990),
        max: DateTime(2030),
        error: (_) => 'Too soon.',
      );
    });
    expect(find.text('Too soon.'), findsOneWidget);
    await t.tap(find.text('Confirm'), warnIfMissed: false);
    await t.pumpAndSettle();
    expect(got, isNull);
  });

  testWidgets('PickerField shows value, hint and error', (t) async {
    var taps = 0;
    Widget field({String? value, String? error}) => MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: PickerField(
          label: 'Category',
          hint: 'Select category',
          valueText: value,
          errorText: error,
          onTap: () => taps++,
        ),
      ),
    );
    await t.pumpWidget(field(error: 'Pick one.'));
    expect(find.text('Select category'), findsOneWidget);
    expect(find.text('Pick one.'), findsOneWidget);
    await t.tap(find.text('Select category'));
    expect(taps, 1);
    await t.pumpWidget(field(value: 'Food and cafes'));
    expect(find.text('Food and cafes'), findsOneWidget);
    expect(find.text('Select category'), findsNothing);
  });
}
