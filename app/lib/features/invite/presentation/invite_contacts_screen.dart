import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/user_avatar.dart';
import '../invite_service.dart';

/// Pick friends from the address book and text each an invite. Contacts are
/// read on the device only; the invitation opens in the messaging app.
class InviteContactsScreen extends StatefulWidget {
  const InviteContactsScreen({
    super.key,
    this.source = const DeviceContactsSource(),
    this.launcher = const DeviceInviteLauncher(),
  });

  final ContactsSource source;
  final InviteLauncher launcher;

  @override
  State<InviteContactsScreen> createState() => _InviteContactsScreenState();
}

enum _Stage { intro, loading, denied, blocked, ready, failed }

class _InviteContactsScreenState extends State<InviteContactsScreen> {
  _Stage _stage = _Stage.intro;
  List<InviteContact> _all = const [];
  final _invited = <String>{};
  String _q = '';

  Future<void> _allow() async {
    setState(() => _stage = _Stage.loading);
    try {
      final access = await widget.source.requestAccess();
      if (!mounted) return;
      if (access == ContactsAccess.granted) {
        final contacts = await widget.source.load();
        if (!mounted) return;
        setState(() {
          _all = contacts;
          _stage = _Stage.ready;
        });
      } else {
        setState(
          () => _stage = access == ContactsAccess.permanentlyDenied
              ? _Stage.blocked
              : _Stage.denied,
        );
      }
    } catch (_) {
      if (mounted) setState(() => _stage = _Stage.failed);
    }
  }

  Future<void> _invite(InviteContact c) async {
    final ok = await widget.launcher.sms(c.phone, inviteMessage());
    if (!mounted) return;
    if (ok) {
      setState(() => _invited.add(c.phone));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Couldn\'t open your messages app.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Invite from contacts')),
      body: SafeArea(child: _body(context)),
    );
  }

  Widget _body(BuildContext context) {
    switch (_stage) {
      case _Stage.intro:
        return EmptyState(
          icon: Icons.contacts_outlined,
          title: 'Find friends to invite',
          message:
              'Allow contacts access to pick friends. Your contacts stay on your phone and are never uploaded.',
          actionLabel: 'Allow contacts access',
          onAction: _allow,
        );
      case _Stage.loading:
        return const Center(child: CircularProgressIndicator());
      case _Stage.denied:
        return EmptyState(
          icon: Icons.lock_outline,
          title: 'Contacts access is off',
          message: 'Allow access to choose friends from your contacts.',
          actionLabel: 'Try again',
          onAction: _allow,
        );
      case _Stage.blocked:
        return EmptyState(
          icon: Icons.lock_outline,
          title: 'Contacts access is off',
          message:
              'Turn on contacts for Nomad Mingle in your phone settings to invite from your contacts.',
          actionLabel: 'Open settings',
          onAction: widget.source.openSettings,
        );
      case _Stage.failed:
        return EmptyState(
          icon: Icons.error_outline,
          title: 'Couldn\'t load your contacts',
          actionLabel: 'Try again',
          onAction: _allow,
        );
      case _Stage.ready:
        return _list(context);
    }
  }

  Widget _list(BuildContext context) {
    final t = Theme.of(context);
    final q = _q.trim().toLowerCase();
    final shown = [
      for (final c in _all)
        if (q.isEmpty ||
            c.name.toLowerCase().contains(q) ||
            c.phone.contains(q))
          c,
    ];
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: TextField(
            onChanged: (v) => setState(() => _q = v),
            decoration: const InputDecoration(
              hintText: 'Search contacts',
              prefixIcon: Icon(Icons.search),
            ),
          ),
        ),
        Expanded(
          child: shown.isEmpty
              ? EmptyState(
                  icon: Icons.person_search_outlined,
                  title: _all.isEmpty
                      ? 'No contacts with numbers'
                      : 'No matches',
                )
              : ListView.builder(
                  itemCount: shown.length,
                  itemBuilder: (_, i) {
                    final c = shown[i];
                    final done = _invited.contains(c.phone);
                    return ListTile(
                      contentPadding: AppSpacing.page,
                      leading: UserAvatar(name: c.name, size: 40),
                      title: Text(c.name, maxLines: 1),
                      subtitle: Text(c.phone, maxLines: 1),
                      trailing: done
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.check,
                                  size: 18,
                                  color: AppColors.success,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Invited',
                                  style: t.textTheme.labelMedium?.copyWith(
                                    color: AppColors.success,
                                  ),
                                ),
                              ],
                            )
                          : OutlinedButton(
                              key: ValueKey('invite-${c.phone}'),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(80, 40),
                              ),
                              onPressed: () => _invite(c),
                              child: const Text('Invite'),
                            ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
