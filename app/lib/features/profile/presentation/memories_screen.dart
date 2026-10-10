import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/app_exception.dart';
import '../../../core/utils/category_style.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../activities/data/my_activities_repository.dart';
import '../../activities/models/activity.dart';

/// Memories: meetups the user hosted or attended that have already happened.
/// Cancelled plans are left out (nothing took place). Pages with "Load more".
class MemoriesScreen extends StatefulWidget {
  const MemoriesScreen({super.key});

  @override
  State<MemoriesScreen> createState() => _MemoriesScreenState();
}

class _MemoriesScreenState extends State<MemoriesScreen> {
  final _items = <MyActivity>[];
  String? _cursor;
  bool _loading = true;
  bool _more = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool more = false}) async {
    final repo = context.read<MyActivitiesRepository>();
    setState(() {
      _error = null;
      if (more) {
        _more = true;
      } else {
        _loading = true;
      }
    });
    try {
      final page = await repo.list(
        MyActivitiesRole.past,
        cursor: more ? _cursor : null,
      );
      if (!mounted) return;
      setState(() {
        if (!more) _items.clear();
        _items.addAll(
          page.items.where(
            (m) => m.activity.status != ActivityStatus.cancelled,
          ),
        );
        _cursor = page.nextCursor;
      });
    } on AppException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
    if (mounted) {
      setState(() {
        _loading = false;
        _more = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    Widget body;
    if (_loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_error != null && _items.isEmpty) {
      body = ErrorState(message: _error, onRetry: _load);
    } else if (_items.isEmpty) {
      body = const EmptyState(
        icon: Icons.photo_album_outlined,
        title: 'No memories yet',
        message: 'Meetups you host or attend will be kept here afterwards.',
      );
    } else {
      body = RefreshIndicator(
        onRefresh: _load,
        child: ListView.separated(
          padding: AppSpacing.page.copyWith(top: 8, bottom: 24),
          itemCount: _items.length + (_cursor != null ? 1 : 0),
          separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
          itemBuilder: (_, i) {
            if (i == _items.length) {
              return Center(
                child: TextButton(
                  onPressed: _more ? null : () => _load(more: true),
                  child: Text(_more ? 'Loading…' : 'Load more'),
                ),
              );
            }
            return _MemoryCard(item: _items[i]);
          },
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Memories',
          style: t.textTheme.headlineMedium?.copyWith(fontSize: 22),
        ),
      ),
      body: body,
    );
  }
}

class _MemoryCard extends StatelessWidget {
  const _MemoryCard({required this.item});
  final MyActivity item;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final a = item.activity;
    final color = CategoryStyle.color(a.category);
    final went = a.participantCount;
    return Material(
      color: t.colorScheme.surface,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      elevation: 1,
      shadowColor: Colors.black26,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: () => context.push('/activity/${a.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Text(
                    Formatters.activityDate(a.startAt),
                    style: t.textTheme.bodySmall,
                  ),
                  const Spacer(),
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: color.withValues(alpha: 0.14),
                    child: Icon(
                      CategoryStyle.icon(a.category),
                      color: color,
                      size: 20,
                    ),
                  ),
                  const Spacer(),
                  if (a.isHost)
                    const Text('👑', style: TextStyle(fontSize: 18))
                  else
                    const SizedBox(width: 18),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                a.title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: t.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${a.venueName.isEmpty ? '' : '${a.venueName} · '}'
                '$went went',
                style: t.textTheme.bodySmall,
              ),
              if (item.participants.isNotEmpty) ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (final p in item.participants)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Column(
                          children: [
                            UserAvatar(
                              name: p.displayName,
                              photoUrl: p.photoUrl,
                              size: 44,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              p.displayName.split(' ').first,
                              style: t.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
