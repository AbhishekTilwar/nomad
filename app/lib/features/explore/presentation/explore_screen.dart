import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../../core/config/map_config.dart';
import '../../../core/services/location_service.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/activity_card.dart';
import '../../../core/widgets/activity_marker.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_skeleton.dart';
import '../../../core/widgets/map_preview_card.dart';
import '../../profile/data/user_profile.dart';
import 'explore_controller.dart';
import 'filter_sheet.dart';

/// Categories shown as quick chips (the full set lives in the filter sheet).
const _quickCategories = ['food', 'travel', 'sports', 'art', 'hiking', 'music'];

class ExploreScreen extends StatelessWidget {
  const ExploreScreen({super.key, this.communityAction});

  /// Entry point to the global Mingle Community chat (small icon in the app bar).
  final Widget? communityAction;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<ExploreController>();
    final t = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Align(
          alignment: Alignment.centerLeft,
          child: PopupMenuButton<String>(
            tooltip: 'Change city',
            initialValue: c.cityId,
            onSelected: c.setCity,
            itemBuilder: (_) => [
              for (final city in MapConfig.cities)
                PopupMenuItem(value: city.id, child: Text(city.name)),
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: t.colorScheme.surface,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(color: t.colorScheme.outline),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.place, size: 18, color: t.colorScheme.primary),
                  const SizedBox(width: 4),
                  Text(c.city.name, style: t.textTheme.labelLarge),
                  const Icon(Icons.keyboard_arrow_down, size: 20),
                ],
              ),
            ),
          ),
        ),
        actions: [
          IconButton(
            tooltip: c.view == ExploreView.map ? 'Show list' : 'Show map',
            icon: Icon(
              c.view == ExploreView.map
                  ? Icons.view_list_outlined
                  : Icons.map_outlined,
            ),
            onPressed: () => c.setView(
              c.view == ExploreView.map ? ExploreView.list : ExploreView.map,
            ),
          ),
          IconButton(
            tooltip: 'Search plans',
            icon: const Icon(Icons.search),
            onPressed: () => context.go('/discover'),
          ),
          communityAction ??
              IconButton(
                tooltip: 'Mingle Community',
                icon: const Icon(Icons.forum_outlined),
                onPressed: () => context.push('/community'),
              ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          _Chips(controller: c),
          Expanded(child: _Body(controller: c)),
        ],
      ),
    );
  }
}

class _Chips extends StatelessWidget {
  const _Chips({required this.controller});
  final ExploreController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: AppSpacing.page,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Badge(
              isLabelVisible: c.hasActiveFilters,
              smallSize: 9,
              child: IconButton.outlined(
                tooltip: 'Filters',
                icon: const Icon(Icons.tune),
                onPressed: () => FilterSheet.show(context, c),
              ),
            ),
          ),
          _chip('All', c.categories.isEmpty && !c.freeOnly, (_) {
            c.clearCategories();
            c.setFreeOnly(false);
          }),
          for (final id in _quickCategories)
            _chip(
              interestLabel(id).split(' ').first,
              c.categories.contains(id),
              (_) => c.toggleCategory(id),
            ),
          _chip('Free', c.freeOnly, c.setFreeOnly),
        ],
      ),
    );
  }

  Widget _chip(String label, bool selected, ValueChanged<bool> onSelected) =>
      Padding(
        padding: const EdgeInsets.only(right: 8),
        child: FilterChip(
          label: Text(label),
          selected: selected,
          showCheckmark: false,
          onSelected: onSelected,
        ),
      );
}

class _Body extends StatelessWidget {
  const _Body({required this.controller});
  final ExploreController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    if (c.state == LoadState.loading && c.items.isEmpty) {
      return LoadingSkeleton.list();
    }
    if (c.state == LoadState.error && c.items.isEmpty) {
      return ErrorState(message: c.error, onRetry: c.load);
    }
    if (c.view == ExploreView.list) {
      final list = c.visible;
      if (list.isEmpty) {
        return EmptyState(
          icon: Icons.event_busy_outlined,
          title: 'No plans here yet',
          message: 'Be the first to host something in ${c.city.name}.',
          actionLabel: 'Create a plan',
          onAction: () => context.go('/create'),
        );
      }
      return RefreshIndicator(
        onRefresh: c.load,
        child: ListView.separated(
          padding: AppSpacing.page.copyWith(top: 8, bottom: 24),
          itemCount: list.length,
          separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
          itemBuilder: (_, i) => ActivityCard(
            activity: list[i],
            onTap: () => context.push('/activity/${list[i].id}'),
          ),
        ),
      );
    }
    return _MapView(controller: c);
  }
}

class _MapView extends StatefulWidget {
  const _MapView({required this.controller});
  final ExploreController controller;

  @override
  State<_MapView> createState() => _MapViewState();
}

class _MapViewState extends State<_MapView> {
  final _map = MapController();
  final _config = MapConfig.fromEnvironment();
  bool _tilesFailing = false;
  bool _ready = false;
  int _seenFocusTick = 0;

  @override
  void initState() {
    super.initState();
    _seenFocusTick = widget.controller.focusTick;
    widget.controller.addListener(_onController);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onController);
    _map.dispose();
    super.dispose();
  }

  void _onController() {
    final c = widget.controller;
    if (c.focusTick != _seenFocusTick && c.focusPoint != null && _ready) {
      _seenFocusTick = c.focusTick;
      _map.move(c.focusPoint!, c.focusZoom ?? MapConfig.defaultZoom);
    }
  }

  Future<void> _recenter(ExploreController c) async {
    final messenger = ScaffoldMessenger.of(context);
    final location = context.read<LocationService>();
    // Foreground, one-shot, only when the user taps the button.
    final r = await location.current();
    if (!mounted) return;
    final p = r.position;
    if (p == null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(locationMessage(r.outcome)),
          action: r.outcome == LocationOutcome.deniedForever
              ? SnackBarAction(
                  label: 'Settings',
                  onPressed: location.openSettings,
                )
              : null,
        ),
      );
      _map.move(c.city.center, MapConfig.defaultZoom);
      return;
    }
    c.setUserLocation(p);
  }

  void _onMapMoved(MapCamera camera) {
    final c = widget.controller;
    const dist = Distance();
    final b = camera.visibleBounds;
    final km = dist.as(LengthUnit.Kilometer, camera.center, b.northEast);
    c.onViewportChanged(camera.center, km);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final selected = c.selected;
    final items = c.visible;
    final t = Theme.of(context);
    return Stack(
      children: [
        FlutterMap(
          mapController: _map,
          options: MapOptions(
            initialCenter: c.focusPoint ?? c.center,
            initialZoom: c.focusZoom ?? MapConfig.defaultZoom,
            minZoom: 4,
            maxZoom: _config.maxZoom.toDouble(),
            onMapReady: () {
              _ready = true;
              _onController();
            },
            onTap: (_, _) => c.select(null),
            onPositionChanged: (camera, hasGesture) {
              if (hasGesture) _onMapMoved(camera);
            },
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: _config.tileUrlTemplate,
              userAgentPackageName: _config.userAgentPackageName,
              maxNativeZoom: _config.maxZoom,
              keepBuffer: 1,
              errorTileCallback: (_, _, _) {
                if (!_tilesFailing && mounted) {
                  setState(() => _tilesFailing = true);
                }
              },
            ),
            MarkerLayer(
              markers: [
                for (final a in items)
                  Marker(
                    point: a.position,
                    width: ActivityMarker.size,
                    height: ActivityMarker.size + 8,
                    alignment: Alignment.topCenter,
                    child: GestureDetector(
                      onTap: () => c.select(a.id),
                      child: ActivityMarker(
                        category: a.category,
                        selected: a.id == c.selectedId,
                        full: a.isFull,
                      ),
                    ),
                  ),
                if (c.userLocation != null)
                  Marker(
                    point: c.userLocation!,
                    width: 22,
                    height: 22,
                    child: Container(
                      decoration: BoxDecoration(
                        color: t.colorScheme.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: AppShadows.card,
                      ),
                    ),
                  ),
              ],
            ),
            RichAttributionWidget(
              alignment: AttributionAlignment.bottomLeft,
              attributions: [TextSourceAttribution(_config.attribution)],
            ),
          ],
        ),
        if (_tilesFailing)
          Positioned(
            top: 8,
            left: 16,
            right: 16,
            child: Material(
              color: t.colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: ListTile(
                dense: true,
                leading: const Icon(Icons.map_outlined),
                title: const Text('Map couldn\'t load'),
                trailing: TextButton(
                  onPressed: () => c.setView(ExploreView.list),
                  child: const Text('Use list'),
                ),
              ),
            ),
          ),
        if (c.state == LoadState.loaded && items.isEmpty)
          Positioned(
            top: 8,
            left: 16,
            right: 16,
            child: Card(
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Text('No plans in this area yet. Try moving the map.'),
              ),
            ),
          ),
        if (c.state == LoadState.loading && c.items.isNotEmpty)
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(minHeight: 2),
          ),
        Positioned(
          right: 16,
          bottom: selected == null ? 16 : 140,
          child: FloatingActionButton.small(
            heroTag: 'recenter',
            tooltip: 'Use my location',
            backgroundColor: t.colorScheme.surface,
            foregroundColor: t.colorScheme.primary,
            onPressed: () => _recenter(c),
            child: const Icon(Icons.near_me_outlined),
          ),
        ),
        if (selected != null)
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: MapPreviewCard(
              activity: selected,
              onTap: () => context.push('/activity/${selected.id}'),
            ),
          ),
      ],
    );
  }
}
