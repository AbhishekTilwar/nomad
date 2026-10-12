import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/secondary_button.dart';
import '../invite_service.dart';
import '../../../core/theme/theme_colors.dart';

/// Invite friends: WhatsApp, contacts (via SMS), or copy / share the link.
class InviteScreen extends StatelessWidget {
  const InviteScreen({super.key, this.launcher = const DeviceInviteLauncher()});

  final InviteLauncher launcher;

  void _toast(BuildContext context, String message) =>
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));

  Future<void> _whatsapp(BuildContext context) async {
    final ok = await launcher.whatsapp(inviteMessage());
    if (!ok && context.mounted) {
      _toast(context, 'Couldn\'t open WhatsApp. Try "More ways to share".');
    }
  }

  Future<void> _copy(BuildContext context) async {
    await launcher.copy(AppConfig.inviteUrl);
    if (context.mounted) _toast(context, 'Link copied');
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Invite friends')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.xl),
              decoration: BoxDecoration(
                color: context.primaryLight,
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: Column(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.group_add_outlined,
                      size: 30,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Plans are better together',
                    textAlign: TextAlign.center,
                    style: t.textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Invite friends to join you on Nomad Mingle and make your next plan.',
                    textAlign: TextAlign.center,
                    style: t.textTheme.bodyMedium?.copyWith(
                      color: context.inkMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            PrimaryButton(
              key: const ValueKey('invite-whatsapp'),
              label: 'Share on WhatsApp',
              icon: Icons.chat_outlined,
              onPressed: () => _whatsapp(context),
            ),
            const SizedBox(height: AppSpacing.md),
            SecondaryButton(
              key: const ValueKey('invite-contacts'),
              label: 'Invite from contacts',
              icon: Icons.contacts_outlined,
              onPressed: () => context.push('/invite/contacts'),
            ),
            const SizedBox(height: AppSpacing.md),
            SecondaryButton(
              key: const ValueKey('invite-share'),
              label: 'More ways to share',
              icon: Icons.ios_share,
              onPressed: () => launcher.share(inviteMessage()),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text('Your invite link', style: t.textTheme.labelMedium),
            const SizedBox(height: AppSpacing.sm),
            Material(
              color: context.field,
              borderRadius: BorderRadius.circular(AppRadius.field),
              child: InkWell(
                key: const ValueKey('invite-copy'),
                borderRadius: BorderRadius.circular(AppRadius.field),
                onTap: () => _copy(context),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.link,
                        color: context.inkMuted,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          AppConfig.inviteUrl,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.textTheme.bodyLarge,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Copy',
                        style: t.textTheme.labelLarge?.copyWith(
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
