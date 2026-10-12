import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nomad_mingle/core/theme/app_theme.dart';
import 'package:nomad_mingle/core/theme/app_tokens.dart';
import 'package:nomad_mingle/core/theme/theme_colors.dart';
import 'package:nomad_mingle/core/utils/category_style.dart';
import 'package:nomad_mingle/core/widgets/picker_sheets.dart';

Future<BuildContext> _ctx(WidgetTester t, ThemeData theme) async {
  late BuildContext ctx;
  await t.pumpWidget(
    MaterialApp(
      theme: theme,
      home: Builder(
        builder: (c) {
          ctx = c;
          return const SizedBox();
        },
      ),
    ),
  );
  // MaterialApp animates theme changes; let it land on the new theme.
  await t.pumpAndSettle();
  return ctx;
}

void main() {
  testWidgets('light theme keeps the light palette', (t) async {
    final c = await _ctx(t, AppTheme.light);
    expect(c.field, AppColors.field);
    expect(c.tint, AppColors.primaryLight);
    expect(c.ink, AppTheme.light.colorScheme.onSurface);
  });

  testWidgets('dark theme swaps in dark neutrals', (t) async {
    final c = await _ctx(t, AppTheme.dark);
    expect(c.field, AppColors.fieldDark);
    expect(c.tint, AppColors.tintDark);
    expect(c.ink, AppTheme.dark.colorScheme.onSurface);
    // Text on dark must be light, never the light-mode ink.
    expect(c.ink.computeLuminance(), greaterThan(0.5));
    expect(c.sand, AppTheme.dark.scaffoldBackgroundColor);
  });

  testWidgets('category text colour is lifted on dark only', (t) async {
    final light = await _ctx(t, AppTheme.light);
    expect(
      CategoryStyle.textColor(light, 'photography'),
      CategoryStyle.color('photography'),
    );
    final dark = await _ctx(t, AppTheme.dark);
    expect(
      CategoryStyle.textColor(dark, 'photography').computeLuminance(),
      greaterThan(CategoryStyle.color('photography').computeLuminance()),
    );
  });

  testWidgets('PickerField text is readable in dark mode', (t) async {
    await t.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: PickerField(
            label: 'Date',
            hint: 'Pick',
            valueText: 'Tue, 13 Oct',
            onTap: () {},
          ),
        ),
      ),
    );
    final text = t.widget<Text>(find.text('Tue, 13 Oct'));
    expect(text.style!.color!.computeLuminance(), greaterThan(0.5));
  });
}
