import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../../core/config/map_config.dart';
import '../../../core/services/location_service.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/category_style.dart';
import '../../../core/widgets/activity_card.dart';
import '../../../core/widgets/app_chip.dart';
import '../../../core/widgets/activity_marker.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_skeleton.dart';
import '../../../core/widgets/plan_sheet_card.dart';
import 'explore_controller.dart';
import '../../social/presentation/travelers_sheet.dart';
import 'filter_screen.dart';

/// Categories shown as quick chips (the full set lives in the filter sheet).
const _quickCategories = ['food', 'travel', 'sports', 'art', 'hiking', 'music'];

class ExploreScreen extends StatelessWidget {
  const ExploreScreen({super.key, this.communityAction});

  /// Entry point to the global Mingle Community chat (small icon in the header).
  final Widget? communityAction;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<ExploreController>();
    final isMap = c.view == ExploreView.map;
    final header = _Header(controller: c, communityAction: communityAction);
    return Scaffold(
      body: isMap
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
    );
  }
}

/// City pill + round action buttons + category chips, floating over the map
/// (solid white in list mode).
class _Header extends StatelessWidget {
  const _Header({required this.controller, this.communityAction});
  final ExploreController controller;
  final Widget? communityAction;

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
              _RoundAction(
                tooltip: isMap ? 'Show list' : 'Show map',
                icon: isMap ? Icons.view_list_outlined : Icons.map_outlined,
                onPressed: () =>
                    c.setView(isMap ? ExploreView.list : ExploreView.map),
              ),
              const SizedBox(width: 8),
              _RoundAction(
                tooltip: 'Travelers nearby',
                icon: Icons.groups_outlined,
                onPressed: () => TravelersSheet.show(context),
              ),
              const SizedBox(width: 8),
              _RoundAction(
                tooltip: 'Mingle Community',
                icon: Icons.forum_outlined,
                child: communityAction,
                onPressed: () => context.push('/community'),
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
    this.child,
  });
  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  /// Replaces the default icon button (e.g. the unread-badge community button).
  final Widget? child;

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
      child:
          child ??
          IconButton(
            tooltip: tooltip,
            padding: EdgeInsets.zero,
            icon: Icon(icon, size: 20),
            onPressed: onPressed,
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

  /// First time the map is shown: ask for permission and centre on the user.
  /// Silent on failure (the city view is a fine fallback; the button retries).
  Future<void> _autoLocate() async {
    final c = widget.controller;
    if (c.autoLocateDone) return;
    c.autoLocateDone = true;
    final r = await context.read<LocationService>().current();
    if (!mounted || r.position == null) return;
    c.setUserLocation(r.position!);
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
                    width: ActivityMarker.width,
                    height: ActivityMarker.height,
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
                  child: const Text('Use list'),
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
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Text('No plans in this area yet. Try moving the map.'),
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
          bottom: selected == null ? 16 : 330,
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
            child: PlanSheetCard(
              activity: selected,
              onClose: () => c.select(null),
            ),
          ),
      ],
    );
  }
}
