import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/app_exception.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../profile/data/user_profile.dart';

/// Read-only public profile preview opened from a chat message (`GET /users/:uid`).
class MemberProfileSheet extends StatefulWidget {
  const MemberProfileSheet({
    super.key,
    required this.uid,
    required this.fallbackName,
    this.fallbackPhotoUrl,
  });
  final String uid;
  final String fallbackName;
  final String? fallbackPhotoUrl;

  static Future<void> show(
    BuildContext context, {
    required String uid,
    required String name,
    String? photoUrl,
  }) => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => MemberProfileSheet(
      uid: uid,
      fallbackName: name,
      fallbackPhotoUrl: photoUrl,
    ),
  );

  @override
  State<MemberProfileSheet> createState() => _MemberProfileSheetState();
}

class _MemberProfileSheetState extends State<MemberProfileSheet> {
  UserProfile? _profile;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await context.read<ApiClient>().get('/users/${widget.uid}');
      if (mounted) setState(() => _profile = UserProfile.fromJson(res.asMap));
    } on AppException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final p = _profile;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          0,
          AppSpacing.xl,
          AppSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            UserAvatar(
              name: p?.displayName ?? widget.fallbackName,
              photoUrl: p?.photoUrl ?? widget.fallbackPhotoUrl,
              size: 72,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              p?.displayName ?? widget.fallbackName,
              style: t.textTheme.titleLarge,
            ),
            if (p != null && p.city.isNotEmpty)
              Text(
                p.city[0].toUpperCase() + p.city.substring(1),
                style: t.textTheme.bodyMedium?.copyWith(
                  color: t.colorScheme.onSurfaceVariant,
                ),
              ),
            const SizedBox(height: AppSpacing.md),
            if (_error != null)
              Text(_error!, textAlign: TextAlign.center)
            else if (p == null)
              const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else ...[
              if (p.bio.isNotEmpty) Text(p.bio, textAlign: TextAlign.center),
              if (p.interests.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  alignment: WrapAlignment.center,
                  children: [for (final i in p.interests) Chip(label: Text(i))],
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
