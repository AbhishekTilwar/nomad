import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
  Widget build(BuildContext context) => OutlinedButton(
    onPressed: _busy ? null : _signIn,
    child: _busy
        ? const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          )
        : const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.g_mobiledata, size: 30),
              SizedBox(width: 6),
              Text('Continue with Google'),
            ],
          ),
  );
}
