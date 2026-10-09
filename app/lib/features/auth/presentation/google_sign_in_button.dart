import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_tokens.dart';
import '../data/auth_repository.dart';

/// "Continue with Google" with its own busy state and friendly errors.
class GoogleSignInButton extends StatefulWidget {
  const GoogleSignInButton({super.key, this.onBusyChanged});
  final ValueChanged<bool>? onBusyChanged;

  @override
  State<GoogleSignInButton> createState() => _GoogleSignInButtonState();
}

class _GoogleSignInButtonState extends State<GoogleSignInButton> {
  bool _busy = false;

  Future<void> _signIn() async {
    setState(() => _busy = true);
    widget.onBusyChanged?.call(true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<AuthRepository>().signInWithGoogle();
    } on AuthFailure catch (e) {
      if (e.code != 'cancelled') {
        messenger.showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
      widget.onBusyChanged?.call(false);
    }
  }

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Continue with Google',
    excludeSemantics: true,
    child: OutlinedButton(
      onPressed: _busy ? null : _signIn,
      child: _busy
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const _GoogleG(),
                const SizedBox(width: 10),
                Text(
                  'Google',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
    ),
  );
}

/// Simple brand-colored "G" mark (no asset needed).
class _GoogleG extends StatelessWidget {
  const _GoogleG();

  @override
  Widget build(BuildContext context) => ShaderMask(
    shaderCallback: (r) => const LinearGradient(
      colors: [
        Color(0xFF4285F4),
        Color(0xFFEA4335),
        Color(0xFFFBBC05),
        Color(0xFF34A853),
      ],
      stops: [0.0, 0.35, 0.65, 1.0],
    ).createShader(r),
    blendMode: BlendMode.srcIn,
    child: const Text(
      'G',
      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
    ),
  );
}
