import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../create/presentation/create_activity_screen.dart';
import '../../../core/config/map_config.dart';
import '../../../core/widgets/basemap_layer.dart';
import '../../../core/services/location_service.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/category_style.dart';
import '../../../core/widgets/activity_card.dart';
import '../../../core/widgets/app_chip.dart';
import '../../../core/widgets/plan_pin.dart';
import '../../../core/widgets/user_location_marker.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_skeleton.dart';
import '../../../core/widgets/plan_sheet_card.dart';
import 'explore_controller.dart';
import 'map_clustering.dart';
import '../../social/data/social_repository.dart';
import '../../social/presentation/travelers_sheet.dart';
import 'filter_screen.dart';

/// Categories shown as quick chips (the full set lives in the filter sheet).
const _quickCategories = ['food', 'travel', 'sports', 'art', 'hiking', 'music'];

class ExploreScreen extends StatelessWidget {
  const ExploreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<ExploreController>();
    final isMap = c.view == ExploreView.map;
    final header = _Header(controller: c);
    // The shell's floating nav bar overlays this screen; MediaQuery's bottom
    // padding already includes its height, so floating controls clear it.
    final pad = MediaQuery.paddingOf(context).bottom + 36;
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          isMap
              ? Stack(
                  fit: StackFit.expand,
                  children: [
                    Positioned.fill(child: _Body(controller: c)),
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: SafeArea(bottom: false, child: header),
                    ),
                  ],
                )
              : SafeArea(
                  bottom: false,
                  child: Column(
                    children: [
                      header,
                      Expanded(child: _Body(controller: c)),
                    ],
                  ),
                ),
          if (!(isMap && c.selected != null))
            Positioned(
              right: 16,
              bottom: pad,
              child: FloatingActionButton(
                heroTag: 'create-plan',
                tooltip: 'Create a plan',
                onPressed: () => showCreatePlanSheet(context),
                child: const Icon(Icons.add),
              ),
            ),
          if (!(isMap && c.selected != null))
            Positioned(
              left: 16,
              bottom: pad,
              child: _ViewToggle(
                isMap: isMap,
                onPressed: () =>
                    c.setView(isMap ? ExploreView.list : ExploreView.map),
              ),
            ),
        ],
      ),
    );
  }
}

/// City pill + round action buttons + category chips, floating over the map
/// (solid white in list mode).
class _Header extends StatelessWidget {
  const _Header({required this.controller});
  final ExploreController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final t = Theme.of(context);
    final isMap = c.view == ExploreView.map;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            children: [
              PopupMenuButton<String>(
                tooltip: 'Change city',
                initialValue: c.cityId,
                onSelected: c.setCity,
                itemBuilder: (_) => [
                  for (final city in MapConfig.cities)
                    PopupMenuItem(value: city.id, child: Text(city.name)),
                ],
                child: Container(
                  height: 36,
                  padding: const EdgeInsets.only(left: 10, right: 6),
                  decoration: BoxDecoration(
                    color: t.colorScheme.surface,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    border: Border.all(color: t.colorScheme.outline),
                    boxShadow: isMap ? AppShadows.card : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.place, size: 16, color: t.colorScheme.primary),
                      const SizedBox(width: 4),
                      Text(
                        c.city.name,
                        style: t.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Icon(Icons.keyboard_arrow_down, size: 18),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              _NearbyPill(
                label: c.nearbyLabel,
                onPressed: () => TravelersSheet.show(context),
              ),
              const SizedBox(width: 8),
              _RoundAction(
                tooltip: 'Notifications',
                icon: Icons.notifications_none,
                onPressed: () => context.push('/notifications'),
              ),
            ],
          ),
        ),
        _Chips(controller: c),
      ],
    );
  }
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });
  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: t.colorScheme.surface,
        shape: BoxShape.circle,
        border: Border.all(color: t.colorScheme.outline),
        boxShadow: AppShadows.card,
      ),
      child: IconButton(
        tooltip: tooltip,
        padding: EdgeInsets.zero,
        icon: Icon(icon, size: 20),
        onPressed: onPressed,
      ),
    );
  }
}

/// "12+ nearby": opens the travelers sheet.
class _NearbyPill extends StatelessWidget {
  const _NearbyPill({required this.label, required this.onPressed});
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Semantics(
      button: true,
      label: 'Travelers $label',
      child: Material(
        color: t.colorScheme.surface,
        shape: StadiumBorder(side: BorderSide(color: t.colorScheme.outline)),
        elevation: 2,
        shadowColor: Colors.black26,
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.groups_outlined,
                  size: 18,
                  color: t.colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: t.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Bottom-left "Browse" / "Map" switch.
class _ViewToggle extends StatelessWidget {
  const _ViewToggle({required this.isMap, required this.onPressed});
  final bool isMap;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Material(
      color: t.colorScheme.surface,
      shape: const StadiumBorder(),
      elevation: 4,
      shadowColor: Colors.black38,
      child: InkWell(
        key: const ValueKey('view-toggle'),
        customBorder: const StadiumBorder(),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(isMap ? Icons.auto_awesome_mosaic_rounded : Icons.map, size: 20),
              const SizedBox(width: 8),
              Text(
                isMap ? 'Browse' : 'Map',
                style: t.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
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
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        clipBehavior: Clip.none,
        children: [
          _gap(
            AppChip(
              label: 'All',
              selected: c.categories.isEmpty && !c.freeOnly,
              onSelected: (_) {
                c.clearCategories();
                c.setFreeOnly(false);
              },
            ),
          ),
          for (final id in _quickCategories)
            _gap(
              AppChip(
                label: CategoryStyle.shortLabels[id] ?? id,
                selected: c.categories.contains(id),
                onSelected: (_) => c.toggleCategory(id),
              ),
            ),
          _gap(
            AppChip(
              label: 'Free',
              selected: c.freeOnly,
              onSelected: c.setFreeOnly,
            ),
          ),
          Badge(
            isLabelVisible: c.hasActiveFilters,
            smallSize: 9,
            child: AppChip(
              label: 'Filters',
              icon: Icons.tune,
              onSelected: (_) => FilterScreen.open(context, c),
            ),
          ),
        ],
      ),
    );
  }

  Widget _gap(Widget w) =>
      Padding(padding: const EdgeInsets.only(right: 8), child: w);
}

class _Body extends StatelessWidget {
  const _Body({required this.controller});
  final ExploreController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    // Map view always renders the map (it shows its own progress/error UI);
    // list view shows skeleton / error states.
    if (c.view == ExploreView.list) {
      if (c.state == LoadState.loading && c.items.isEmpty) {
        return LoadingSkeleton.list();
      }
      if (c.state == LoadState.error && c.items.isEmpty) {
        return ErrorState(message: c.error, onRetry: c.load);
      }
    }
    if (c.view == ExploreView.list) {
      final list = c.visible;
      if (list.isEmpty) {
        // Filters hiding everything is a different situation from a city
        // with no plans: offer the way out first.
        if (c.hasActiveFilters) {
          return EmptyState(
            icon: Icons.filter_alt_off_outlined,
            title: 'No plans match your filters',
            message:
                'Try removing a filter to see everything in ${c.city.name}.',
            actionLabel: 'Clear filters',
            onAction: c.clearFilters,
          );
        }
        return EmptyState(
          icon: Icons.event_busy_outlined,
          title: 'No plans here yet',
          message:
              'Nothing is scheduled in ${c.city.name} right now. Host a coffee or a walk and others can join you.',
          actionLabel: 'Create a plan',
          onAction: () => showCreatePlanSheet(context),
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
            // The marker feed measures from the map centre, not the member.
            showServerDistance: false,
            distanceFrom: c.userLocation,
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
  bool _locating = false;
  int _seenFocusTick = 0;
  String? _seenSelectedId;

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

  /// The plan card covers the lower half of the map; slide the selected pin
  /// up into the visible part so it isn't hidden behind it.
  void _revealSelected() {
    final a = widget.controller.selected;
    if (a == null || !_ready) return;
    final cam = _map.camera;
    final h = cam.nonRotatedSize.height;
    final pinY = cam.latLngToScreenOffset(a.position).dy;
    final target = (h - 420) / 2 + 40;
    if (pinY > 90 && pinY < h - 460) return;
    final shifted = cam.projectAtZoom(a.position) + Offset(0, h / 2 - target);
    _map.move(cam.unprojectAtZoom(shifted), cam.zoom);
  }

  void _onController() {
    final c = widget.controller;
    if (c.selectedId != _seenSelectedId) {
      _seenSelectedId = c.selectedId;
      if (c.selectedId != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _revealSelected());
      }
    }
    if (c.focusTick != _seenFocusTick && c.focusPoint != null && _ready) {
      _seenFocusTick = c.focusTick;
      _map.move(c.focusPoint!, c.focusZoom ?? MapConfig.defaultZoom);
    }
  }

  /// First time the map is shown: centre on the user only if location was
  /// already allowed. Never prompts here; the locate button asks, in context.
  Future<void> _autoLocate() async {
    final c = widget.controller;
    if (c.autoLocateDone) return;
    c.autoLocateDone = true;
    final r = await context.read<LocationService>().currentIfPermitted();
    if (!mounted || r.position == null) return;
    c.setUserLocation(r.position!);
    c.loadNearby(context.read<SocialRepository>(), r.position!);
  }

  Future<void> _recenter(ExploreController c) async {
    if (_locating) return;
    final messenger = ScaffoldMessenger.of(context);
    final location = context.read<LocationService>();
    // Foreground, one-shot, only when the user taps the button. Finding a fix
    // can take a few seconds, so the button shows progress meanwhile.
    setState(() => _locating = true);
    final r = await location.current();
    if (!mounted) return;
    setState(() => _locating = false);
    final p = r.position;
    if (p == null) {
      messenger.showSnackBar(
        SnackBar(
          persist: false,
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
    c.loadNearby(context.read<SocialRepository>(), p);
  }

  void _zoomInto(MapCluster g) {
    _map.fitCamera(
      CameraFit.coordinates(
        coordinates: [for (final a in g.items) a.position],
        padding: const EdgeInsets.all(90),
        maxZoom: _config.maxZoom.toDouble(),
      ),
    );
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
              _autoLocate();
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
            BasemapLayer(
              config: _config,
              onTileError: () {
                if (!_tilesFailing && mounted) {
                  setState(() => _tilesFailing = true);
                }
              },
            ),
            // Under the pins so the radar never covers a plan.
            if (c.userLocation != null)
              MarkerLayer(
                markers: [
                  Marker(
                    point: c.userLocation!,
                    width: UserLocationMarker.size,
                    height: UserLocationMarker.size,
                    child: const UserLocationMarker(),
                  ),
                ],
              ),
            Builder(
              builder: (context) {
                final camera = MapCamera.of(context);
                final clusters = clusterActivities(
                  items,
                  camera,
                  keepSingleId: c.selectedId,
                );
                return MarkerLayer(
                  markers: [
                    for (final g in clusters)
                      if (g.isSingle)
                        Marker(
                          point: g.items.first.position,
                          width: PlanPin.width,
                          height: PlanPin.height,
                          alignment: Alignment.topCenter,
                          child: GestureDetector(
                            onTap: () => c.select(g.items.first.id),
                            child: PlanPin(
                              activity: g.items.first,
                              selected: g.items.first.id == c.selectedId,
                            ),
                          ),
                        )
                      else
                        Marker(
                          point: g.center,
                          width: ClusterPin.size,
                          height: ClusterPin.size,
                          child: GestureDetector(
                            onTap: () => _zoomInto(g),
                            child: ClusterPin(items: g.items),
                          ),
                        ),
                  ],
                );
              },
            ),
            Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.paddingOf(context).bottom + 4,
              ),
              child: RichAttributionWidget(
                alignment: AttributionAlignment.bottomRight,
                attributions: [TextSourceAttribution(_config.attribution)],
              ),
            ),
          ],
        ),
        if (_tilesFailing)
          Positioned(
            top: MediaQuery.paddingOf(context).top + 104,
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
                  child: const Text('Browse plans'),
                ),
              ),
            ),
          ),
        if (c.state == LoadState.loaded && items.isEmpty)
          Positioned(
            top: MediaQuery.paddingOf(context).top + 104,
            left: 16,
            right: 16,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        c.hasActiveFilters
                            ? 'No plans match your filters here.'
                            : 'No plans in this area yet.',
                      ),
                    ),
                    TextButton(
                      onPressed: c.hasActiveFilters
                          ? c.clearFilters
                          : () => showCreatePlanSheet(context),
                      child: Text(
                        c.hasActiveFilters ? 'Clear filters' : 'Host one',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        if (c.state == LoadState.error)
          Positioned(
            top: MediaQuery.paddingOf(context).top + 104,
            left: 16,
            right: 16,
            child: Material(
              color: t.colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: ListTile(
                dense: true,
                leading: const Icon(Icons.cloud_off_outlined),
                title: Text(c.error ?? 'Couldn\'t load plans'),
                trailing: TextButton(
                  onPressed: c.load,
                  child: const Text('Try again'),
                ),
              ),
            ),
          ),
        if (c.state == LoadState.loading)
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(minHeight: 2),
          ),
        Positioned(
          right: 16,
          bottom:
              MediaQuery.paddingOf(context).bottom +
              (selected == null ? 112 : 330),
          child: FloatingActionButton.small(
            heroTag: 'recenter',
            tooltip: 'Use my location',
            backgroundColor: t.colorScheme.surface,
            foregroundColor: t.colorScheme.primary,
            onPressed: () => _recenter(c),
            child: _locating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.4),
                  )
                : const Icon(Icons.near_me_outlined),
          ),
        ),
        if (selected != null)
          Positioned(
            left: 16,
            right: 16,
            bottom: MediaQuery.paddingOf(context).bottom + 12,
            child: PlanSheetCard(
              activity: selected,
              onClose: () => c.select(null),
              onChanged: () => c.load(keepSelection: true),
            ),
          ),
      ],
    );
  }
}
