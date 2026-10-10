import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/primary_button.dart';
import '../data/auth_repository.dart';
import 'auth_fields.dart';
import 'auth_layout.dart';
import 'google_sign_in_button.dart';

/// Email + password sign-in.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<AuthRepository>().signInWithEmail(
        _email.text,
        _password.text,
      );
      // Router reacts to the session change; nothing else to do here.
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthPage(
      title: 'Welcome back',
      subtitle: 'Sign in to continue',
      footer: AuthSwitchRow(
        prompt: 'Don\'t have an account?',
        action: 'Sign Up',
        onPressed: _busy ? null : () => context.pushReplacement('/register'),
      ),
      children: [
        const GoogleSignInButton(),
        const SizedBox(height: 16),
        const OrDivider(),
        const SizedBox(height: 16),
        Form(
          key: _form,
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LabeledAuthField(
                  key: const ValueKey('login-email'),
                  label: 'Email address',
                  hint: 'you@example.com',
                  controller: _email,
                  validator: Validators.email,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email],
                ),
                const SizedBox(height: 14),
                LabeledAuthField(
                  key: const ValueKey('login-password'),
                  label: 'Password',
                  hint: 'Enter your password',
                  controller: _password,
                  obscure: true,
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Enter your password.' : null,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                  autofillHints: const [AutofillHints.password],
                ),
              ],
            ),
          ),
        ),
        if (_error != null) ...[const SizedBox(height: 12), AuthError(_error!)],
        const SizedBox(height: 16),
        PrimaryButton(
          backgroundColor: AppColors.navy,
          label: 'Sign In',
          loading: _busy,
          onPressed: _submit,
        ),
        const SizedBox(height: 4),
        Center(
          child: TextButton(
            style: TextButton.styleFrom(
              minimumSize: const Size(0, 48),
              foregroundColor: AppColors.inkMuted,
            ),
            onPressed: () => context.push('/forgot-password'),
            child: const Text('Forgot password?'),
          ),
        ),
      ],
    );
  }
}
