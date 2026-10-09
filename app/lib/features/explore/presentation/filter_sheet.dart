import 'package:flutter/material.dart';

import '../../../core/config/map_config.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/category_style.dart';
import '../../../core/widgets/primary_button.dart';
import '../../discover/presentation/discover_controller.dart' show DateFilter;
import '../../profile/data/user_profile.dart';
import 'explore_controller.dart';

class FilterResult {
  const FilterResult(this.categories, this.date, this.cityId, this.radiusKm);
  final Set<String> categories;
  final DateFilter date;
  final String cityId;
  final double radiusKm;
}

/// Bottom sheet matching the design: category grid, date, location, radius.
class FilterSheet extends StatefulWidget {
  const FilterSheet({super.key, required this.controller});
  final ExploreController controller;

  static Future<void> show(BuildContext context, ExploreController c) async {
    final result = await showModalBottomSheet<FilterResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => FilterSheet(controller: c),
    );
    if (result != null) {
      c.applyFilters(
        categories: result.categories,
        date: result.date,
        cityId: result.cityId,
        radiusKm: result.radiusKm,
      );
    }
  }

  @override
  State<FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<FilterSheet> {
  late final Set<String> _cats = {...widget.controller.categories};
  late DateFilter _date = widget.controller.dateFilter;
  late String _city = widget.controller.cityId;
  late double _radius = widget.controller.radiusKm;

  void _reset() => setState(() {
    _cats.clear();
    _date = DateFilter.any;
    _radius = 25;
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    Widget label(String s) => Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg, bottom: AppSpacing.sm),
      child: Text(s, style: t.textTheme.titleMedium),
    );

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Filter', style: t.textTheme.titleLarge),
                const Spacer(),
                TextButton(onPressed: _reset, child: const Text('Reset')),
              ],
            ),
            label('Category'),
            GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 8,
              childAspectRatio: 0.85,
              children: [
                for (final i in kInterests)
                  _CategoryTile(
                    id: i.id,
                    label: i.label.split(' ').first,
                    selected: _cats.contains(i.id),
                    onTap: () => setState(
                      () => _cats.contains(i.id)
                          ? _cats.remove(i.id)
                          : _cats.add(i.id),
                    ),
                  ),
              ],
            ),
            label('Date'),
            SegmentedButton<DateFilter>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: DateFilter.any, label: Text('Any')),
                ButtonSegment(value: DateFilter.today, label: Text('Today')),
                ButtonSegment(
                  value: DateFilter.weekend,
                  label: Text('Weekend'),
                ),
                ButtonSegment(value: DateFilter.week, label: Text('Week')),
              ],
              selected: {_date},
              onSelectionChanged: (s) => setState(() => _date = s.first),
            ),
            label('Location'),
            SegmentedButton<String>(
              showSelectedIcon: false,
              segments: [
                for (final c in MapConfig.cities)
                  ButtonSegment(value: c.id, label: Text(c.name)),
              ],
              selected: {_city},
              onSelectionChanged: (s) => setState(() => _city = s.first),
            ),
            label('Radius'),
            Row(
              children: [
                Expanded(
                  child: Slider(
                    value: _radius,
                    min: 1,
                    max: 50,
                    divisions: 49,
                    label: '${_radius.round()} km',
                    onChanged: (v) => setState(() => _radius = v),
                  ),
                ),
                SizedBox(
                  width: 52,
                  child: Text(
                    '${_radius.round()} km',
                    textAlign: TextAlign.end,
                    style: t.textTheme.labelLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            PrimaryButton(
              label: 'Apply',
              onPressed: () => Navigator.pop(
                context,
                FilterResult({..._cats}, _date, _city, _radius),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.id,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String id;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final primary = t.colorScheme.primary;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: AppMotion.fast,
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? primary : t.colorScheme.surface,
                border: Border.all(
                  color: selected ? primary : t.colorScheme.outline,
                ),
              ),
              child: Icon(
                CategoryStyle.icon(id),
                color: selected ? Colors.white : t.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: t.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
