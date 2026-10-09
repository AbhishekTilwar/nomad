import 'package:flutter/material.dart';

import '../../../core/config/map_config.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/category_style.dart';
import '../../../core/widgets/app_chip.dart';
import '../../../core/widgets/primary_button.dart';
import '../../discover/presentation/discover_controller.dart' show DateFilter;
import '../../profile/data/user_profile.dart';
import 'explore_controller.dart';

/// Full-screen filters (design #12): category tiles, date, location, radius.
class FilterScreen extends StatefulWidget {
  const FilterScreen({super.key, required this.controller});
  final ExploreController controller;

  static Future<void> open(BuildContext context, ExploreController c) =>
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => FilterScreen(controller: c)),
      );

  @override
  State<FilterScreen> createState() => _FilterScreenState();
}

class _FilterScreenState extends State<FilterScreen> {
  late final Set<String> _cats = {...widget.controller.categories};
  late DateFilter _date = widget.controller.dateFilter;
  late String _city = widget.controller.cityId;
  late double _radius = widget.controller.radiusKm;

  void _reset() => setState(() {
    _cats.clear();
    _date = DateFilter.any;
    _radius = 25;
  });

  void _apply() {
    widget.controller.applyFilters(
      categories: _cats,
      date: _date,
      cityId: _city,
      radiusKm: _radius,
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    Widget label(String s) => Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 12),
      child: Text(s, style: t.textTheme.titleMedium),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Filter'),
        actions: [
          TextButton(
            onPressed: _reset,
            child: Text(
              'Reset',
              style: TextStyle(color: t.colorScheme.onSurfaceVariant),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          label('Category'),
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 14,
            crossAxisSpacing: 8,
            childAspectRatio: 0.82,
            children: [
              for (final i in kInterests)
                _CategoryTile(
                  id: i.id,
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
          AppSegmented<DateFilter>(
            options: const {
              DateFilter.today: 'Today',
              DateFilter.weekend: 'This Weekend',
              DateFilter.week: 'Next Week',
            },
            value: _date,
            // Tap the active segment again to clear the date filter.
            onChanged: (v) =>
                setState(() => _date = v == _date ? DateFilter.any : v),
          ),
          label('Location'),
          AppSegmented<String>(
            options: {for (final c in MapConfig.cities) c.id: c.name},
            value: _city,
            onChanged: (v) => setState(() => _city = v),
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
                  semanticFormatterCallback: (v) => '${v.round()} kilometres',
                  onChanged: (v) => setState(() => _radius = v),
                ),
              ),
              SizedBox(
                width: 56,
                child: Text(
                  '${_radius.round()} km',
                  textAlign: TextAlign.end,
                  style: t.textTheme.bodyMedium?.copyWith(
                    color: t.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: PrimaryButton(label: 'Apply', onPressed: _apply),
        ),
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.id,
    required this.selected,
    required this.onTap,
  });
  final String id;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final primary = t.colorScheme.primary;
    final label = CategoryStyle.shortLabels[id] ?? id;
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
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? primary : AppColors.field,
                border: Border.all(
                  color: selected ? primary : t.colorScheme.outline,
                ),
              ),
              child: Icon(
                CategoryStyle.icon(id),
                color: selected ? Colors.white : t.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: t.textTheme.bodySmall?.copyWith(
                color: selected ? primary : t.colorScheme.onSurfaceVariant,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
