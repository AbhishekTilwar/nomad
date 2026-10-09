import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/services/location_service.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/activity_card.dart';
import '../../../core/widgets/app_chip.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_skeleton.dart';
import '../../activities/data/activity_repository.dart';
import '../../auth/application/session_controller.dart';
import '../../profile/data/user_profile.dart';
import 'discover_controller.dart';

class DiscoverScreen extends StatelessWidget {
  const DiscoverScreen({super.key});

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (_) => DiscoverController(
      context.read<ActivityRepository>(),
      context.read<LocationService>(),
      city: context.read<SessionController>().profile?.city ?? 'mumbai',
    ),
    child: const _DiscoverView(),
  );
}

class _DiscoverView extends StatefulWidget {
  const _DiscoverView();

  @override
  State<_DiscoverView> createState() => _DiscoverViewState();
}

class _DiscoverViewState extends State<_DiscoverView> {
  final _scroll = ScrollController();
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 400) {
        context.read<DiscoverController>().loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<DiscoverController>();
    final t = Theme.of(context);

    Widget body;
    if (c.loading && c.items.isEmpty) {
      body = LoadingSkeleton.list();
    } else if (c.error != null && c.items.isEmpty) {
      body = ErrorState(message: c.error, onRetry: c.refresh);
    } else if (c.items.isEmpty) {
      body = EmptyState(
        icon: Icons.search_off,
        title: c.hasActiveFilters ? 'No plans match' : 'No plans yet',
        message: c.hasActiveFilters
            ? 'Try removing a filter or searching for something else.'
            : 'Be the first to host something in your city.',
        actionLabel: c.hasActiveFilters ? 'Clear filters' : 'Host a plan',
        onAction: c.hasActiveFilters
            ? () {
                _search.clear();
                c.clearFilters();
              }
            : () => context.go('/create'),
      );
    } else {
      body = RefreshIndicator(
        onRefresh: c.refresh,
        child: ListView.separated(
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: AppSpacing.page.copyWith(top: 8, bottom: 24),
          itemCount: c.items.length + 1,
          separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
          itemBuilder: (_, i) {
            if (i == c.items.length) {
              if (c.loadingMore) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (c.loadMoreError != null) {
                return Center(
                  child: TextButton(
                    onPressed: c.loadMore,
                    child: Text('${c.loadMoreError} Tap to retry.'),
                  ),
                );
              }
              return const SizedBox.shrink();
            }
            final a = c.items[i];
            return ActivityCard(
              activity: a,
              onTap: () => context.push('/activity/${a.id}'),
            );
          },
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Discover')),
      body: Column(
        children: [
          Padding(
            padding: AppSpacing.page.copyWith(top: 4, bottom: 8),
            child: TextField(
              controller: _search,
              textInputAction: TextInputAction.search,
              onChanged: c.setKeyword,
              onSubmitted: (v) {
                c.setKeyword(v);
                c.refresh();
              },
              decoration: InputDecoration(
                hintText: 'Search plans, places, hosts',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          _search.clear();
                          c.setKeyword('');
                          c.refresh();
                        },
                      ),
              ),
            ),
          ),
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: AppSpacing.page,
              children: [
                _chip(
                  'Today',
                  c.dateFilter == DateFilter.today,
                  (v) => c.setDateFilter(v ? DateFilter.today : DateFilter.any),
                ),
                _chip(
                  'This weekend',
                  c.dateFilter == DateFilter.weekend,
                  (v) =>
                      c.setDateFilter(v ? DateFilter.weekend : DateFilter.any),
                ),
                _chip(
                  'This week',
                  c.dateFilter == DateFilter.week,
                  (v) => c.setDateFilter(v ? DateFilter.week : DateFilter.any),
                ),
                _chip('Free', c.freeOnly, c.setFreeOnly),
                _chip('Spots available', c.spotsOnly, c.setSpotsOnly),
                _chip(
                  'Within 5 km',
                  c.radiusKm == 5,
                  (v) => c.setRadius(v ? 5 : null),
                ),
                _chip(
                  'Within 15 km',
                  c.radiusKm == 15,
                  (v) => c.setRadius(v ? 15 : null),
                ),
                for (final i in kInterests)
                  _chip(
                    i.label,
                    c.category == i.id,
                    (v) => c.setCategory(v ? i.id : null),
                  ),
              ],
            ),
          ),
          Padding(
            padding: AppSpacing.page.copyWith(top: 4, bottom: 0),
            child: Row(
              children: [
                if (c.locationNotice != null)
                  Expanded(
                    child: Text(
                      c.locationNotice!,
                      style: t.textTheme.bodySmall?.copyWith(
                        color: t.colorScheme.error,
                      ),
                    ),
                  )
                else
                  const Spacer(),
                PopupMenuButton<DiscoverSort>(
                  tooltip: 'Sort',
                  initialValue: c.sort,
                  onSelected: c.setSort,
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: DiscoverSort.date,
                      child: Text('Soonest first'),
                    ),
                    PopupMenuItem(
                      value: DiscoverSort.proximity,
                      child: Text('Nearest first'),
                    ),
                    PopupMenuItem(
                      value: DiscoverSort.relevance,
                      child: Text('Most relevant'),
                    ),
                  ],
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.sort, size: 18),
                        const SizedBox(width: 4),
                        Text(switch (c.sort) {
                          DiscoverSort.date => 'Soonest',
                          DiscoverSort.proximity => 'Nearest',
                          DiscoverSort.relevance => 'Relevant',
                        }, style: t.textTheme.labelLarge),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: body),
        ],
      ),
    );
  }

  Widget _chip(String label, bool selected, ValueChanged<bool> onSelected) =>
      Padding(
        padding: const EdgeInsets.only(right: 8),
        child: AppChip(
          label: label,
          selected: selected,
          onSelected: onSelected,
        ),
      );
}
