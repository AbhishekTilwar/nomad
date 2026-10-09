import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/primary_button.dart';
import '../application/session_controller.dart';
import '../data/auth_repository.dart';

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
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: AppSpacing.page,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.mark_email_unread_outlined, size: 64),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Verify your email',
                    style: t.textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'We sent a link to ${session.user?.email ?? 'your email'}. Tap it, then come back here.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  PrimaryButton(
                    label: 'I\'ve verified my email',
                    loading: _checking,
                    onPressed: _check,
                  ),
                  TextButton(
                    onPressed: _resend,
                    child: const Text('Resend email'),
                  ),
                  TextButton(
                    onPressed: () => session.signOut(),
                    child: const Text('Use a different account'),
                  ),
                  if (_message != null)
                    Semantics(
                      liveRegion: true,
                      child: Text(_message!, textAlign: TextAlign.center),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
