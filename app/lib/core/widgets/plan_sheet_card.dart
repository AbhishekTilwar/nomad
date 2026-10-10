import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../features/activities/data/activity_repository.dart';
import '../../features/activities/models/activity.dart';
import '../../features/safety/data/safety_repository.dart';
import '../services/translation_service.dart';
import '../theme/app_tokens.dart';
import '../utils/app_exception.dart';
import '../utils/category_style.dart';
import '../utils/formatters.dart';
import 'join_activity_button.dart';
import 'report_action_sheet.dart';
import 'user_avatar.dart';

/// Quick-look card shown over the map for the selected pin: category badge,
/// title, headcount, host (crown) + attendee avatars, and a one-tap
/// Join / Request / Join Chat action. Tap the title area for full details.
class PlanSheetCard extends StatefulWidget {
  const PlanSheetCard({
    super.key,
    required this.activity,
    required this.onClose,
  });
  final Activity activity;
  final VoidCallback onClose;

  @override
  State<PlanSheetCard> createState() => _PlanSheetCardState();
}

class _PlanSheetCardState extends State<PlanSheetCard> {
  Activity? _full;
  List<ActivityMember> _members = const [];
  bool _busy = false;
  bool _translating = false;
  String? _translated;

  Activity get _a => _full ?? widget.activity;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(PlanSheetCard old) {
    super.didUpdateWidget(old);
    if (old.activity.id != widget.activity.id) {
      _full = null;
      _members = const [];
      _translated = null;
      _load();
    }
  }

  Future<void> _load() async {
    final repo = context.read<ActivityRepository>();
    final id = widget.activity.id;
    try {
      final results = await Future.wait([repo.get(id), repo.members(id)]);
      if (!mounted || id != widget.activity.id) return;
      setState(() {
        _full = results[0] as Activity;
        _members = (results[1] as List<ActivityMember>)
            .where((m) => m.status == MembershipStatus.approved)
            .toList();
      });
    } on AppException {
      // Keep the slim marker data; the card still works as a link to details.
    }
  }

  Future<void> _translate() async {
    if (_translated != null) {
      setState(() => _translated = null);
      return;
    }
    if (_translating) return;
    final service = context.read<TranslationService>();
    final messenger = ScaffoldMessenger.of(context);
    final a = _a;
    setState(() => _translating = true);
    try {
      final r = await service.translate(a.title);
      if (!mounted) return;
      if (r.text == a.title) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Already in your language.')),
        );
      } else {
        setState(() => _translated = r.text);
      }
    } on TranslationException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
    if (mounted) setState(() => _translating = false);
  }

  Future<void> _share() async {
    final a = _a;
    await SharePlus.instance.share(
      ShareParams(
        subject: a.title,
        text:
            '${a.title}\n${Formatters.activityWhen(a.startAt)}'
            '${a.venueName.isEmpty ? '' : ' · ${a.venueName}'}\n'
            'Join me on Nomad Mingle!',
      ),
    );
  }

  Future<void> _report() async {
    final messenger = ScaffoldMessenger.of(context);
    final safety = context.read<SafetyRepository>();
    final result = await ReportActionSheet.show(
      context,
      title: 'Report this plan',
    );
    if (result == null) return;
    try {
      await safety.report(
        targetType: 'activity',
        targetId: _a.id,
        reason: result.reason.name,
        details: result.details,
      );
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Thanks. Our moderators will review this.'),
        ),
      );
    } on AppException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _join() async {
    if (_busy) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final status = await context.read<ActivityRepository>().join(_a.id);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            status == MembershipStatus.requested
                ? 'Request sent. The host will review it.'
                : 'You\'re in!',
          ),
        ),
      );
    } on AppException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
    if (mounted) {
      await _load();
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final a = _a;
    final color = CategoryStyle.color(a.category);
    final state = joinUiStateFor(a);
    final canChat = state == JoinUiState.joined || state == JoinUiState.hosting;
    final people = a.isSummary ? null : a.participantCount;
    final locked = a.isPrivate && !canChat;

    return Material(
      color: t.colorScheme.surface,
      borderRadius: BorderRadius.circular(AppRadius.xl),
      elevation: 8,
      shadowColor: Colors.black26,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: 'Report plan',
                  color: AppColors.danger,
                  icon: const Icon(Icons.error_outline),
                  onPressed: _report,
                ),
                IconButton(
                  tooltip: 'Share plan',
                  icon: const Icon(Icons.share_outlined),
                  onPressed: _share,
                ),
                IconButton(
                  tooltip: _translated == null ? 'Translate' : 'Show original',
                  isSelected: _translated != null,
                  icon: _translating
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.translate),
                  onPressed: _translate,
                ),
                const SizedBox(width: 4),
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(CategoryStyle.icon(a.category), color: color),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Close',
                  icon: const Icon(Icons.close),
                  onPressed: widget.onClose,
                ),
              ],
            ),
            InkWell(
              onTap: () => context.push('/activity/${a.id}'),
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  children: [
                    Text(
                      _translated ?? a.title,
                      textAlign: TextAlign.center,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: t.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        Formatters.activityWhen(a.startAt),
                        if (a.venueName.isNotEmpty) a.venueName,
                      ].join(' · '),
                      textAlign: TextAlign.center,
                      style: t.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      people == null
                          ? '${a.spotsLeft} spots left'
                          : '$people ${people == 1 ? 'person' : 'people'}',
                      style: t.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: t.textTheme.bodySmall?.color,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            _Attendees(
              host: a,
              members: _members,
              lockedCount: locked ? (a.participantCount - 1).clamp(0, 3) : 0,
            ),
            if (locked) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.field,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.visibility_off_outlined, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Request to join to see attendees',
                      style: t.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: canChat
                  ? FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.success,
                      ),
                      onPressed: () => context.push('/activity/${a.id}/chat'),
                      icon: const Icon(Icons.chat_bubble_outline),
                      label: const Text('Join Chat'),
                    )
                  : JoinActivityButton(
                      state: state,
                      onJoin: _join,
                      onLeave: () => context.push('/activity/${a.id}'),
                      loading: _busy,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Attendees extends StatelessWidget {
  const _Attendees({
    required this.host,
    required this.members,
    this.lockedCount = 0,
  });
  final Activity host;
  final List<ActivityMember> members;
  final int lockedCount;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    Widget person(
      String name,
      String? photo, {
      bool isHost = false,
      String? userId,
    }) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: userId == null || userId.isEmpty
              ? null
              : () => context.push('/user/$userId'),
          child: SizedBox(
            width: 64,
            child: Column(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    UserAvatar(name: name, photoUrl: photo, size: 52),
                    if (isHost)
                      const Positioned(
                        right: -4,
                        bottom: -4,
                        child: Text('👑', style: TextStyle(fontSize: 16)),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  name.split(' ').first,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      );
    }

    final others = members.where((m) => m.userId != host.hostId).take(5);
    return SizedBox(
      height: 80,
      child: ListView(
        scrollDirection: Axis.horizontal,
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        children: [
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                person(
                  host.hostDisplayName,
                  host.hostPhotoUrl,
                  isHost: true,
                  userId: host.hostId,
                ),
                for (final m in others)
                  person(m.displayName, m.photoUrl, userId: m.userId),
                for (var i = 0; i < lockedCount; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: SizedBox(
                      width: 64,
                      child: Column(
                        children: [
                          const CircleAvatar(
                            radius: 26,
                            backgroundColor: AppColors.outline,
                            child: Icon(Icons.lock, color: AppColors.inkMuted),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            height: 10,
                            width: 40,
                            decoration: BoxDecoration(
                              color: AppColors.outline,
                              borderRadius: BorderRadius.circular(5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
