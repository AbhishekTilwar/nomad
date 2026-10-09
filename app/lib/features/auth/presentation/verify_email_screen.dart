import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/secondary_button.dart';
import '../application/session_controller.dart';
import '../data/auth_repository.dart';
import 'auth_layout.dart';

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  bool _checking = false;
  String? _message;

  Future<void> _check() async {
    setState(() {
      _checking = true;
      _message = null;
    });
    try {
      final ok = await context
          .read<SessionController>()
          .refreshEmailVerification();
      if (!ok && mounted) {
        setState(
          () => _message =
              'Not verified yet. Open the link in your email, then try again.',
        );
      }
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _message = e.message);
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _resend() async {
    try {
      await context.read<SessionController>().resendVerification();
      if (mounted) setState(() => _message = 'Verification email sent.');
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _message = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final t = Theme.of(context);
    return AuthPage(
      title: 'Verify your email',
      subtitle:
          'We sent a link to ${session.user?.email ?? 'your email'}. Tap it, then come back here.',
      showBack: false,
      footer: TextButton(
        onPressed: () => session.signOut(),
        child: const Text('Use a different account'),
      ),
      children: [
        Center(
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.tint,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              Icons.mark_email_unread_outlined,
              size: 36,
              color: t.colorScheme.primary,
            ),
          ),
        ),
        const SizedBox(height: 28),
        PrimaryButton(
          label: 'I\'ve verified my email',
          loading: _checking,
          onPressed: _check,
        ),
        const SizedBox(height: 8),
        SecondaryButton(label: 'Resend email', onPressed: _resend),
        if (_message != null) ...[
          const SizedBox(height: 16),
          Semantics(
            liveRegion: true,
            child: Text(
              _message!,
              textAlign: TextAlign.center,
              style: t.textTheme.bodyMedium?.copyWith(
                color: AppColors.inkMuted,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
