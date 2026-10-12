import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/primary_button.dart';
import '../data/auth_repository.dart';
import 'auth_fields.dart';
import 'auth_layout.dart';
import '../../../core/theme/theme_colors.dart';

/// Email registration: credentials only. Name, birthday, city and interests
/// are collected by the same onboarding flow Google users see, so both
/// sign-in methods end up with identical steps and fields.
class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
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
    if (_busy) return;
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final auth = context.read<AuthRepository>();
    try {
      await auth.registerWithEmail(_email.text, _password.text);
      // Router reacts to the session change (email verification gate).
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return AuthPage(
      title: 'Create Your Account',
      subtitle: 'Next, a few quick questions to set up your profile',
      footer: AuthSwitchRow(
        prompt: 'Already have an account?',
        action: 'Login',
        onPressed: _busy ? null : () => context.pushReplacement('/sign-in'),
      ),
      children: [
        Form(
          key: _form,
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LabeledAuthField(
                  key: const ValueKey('signup-email'),
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
                  key: const ValueKey('signup-password'),
                  label: 'Password',
                  hint: 'At least 8 characters',
                  controller: _password,
                  obscure: true,
                  validator: Validators.password,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                  autofillHints: const [AutofillHints.newPassword],
                ),
              ],
            ),
          ),
        ),
        if (_error != null) ...[const SizedBox(height: 12), AuthError(_error!)],
        const SizedBox(height: 16),
        PrimaryButton(
          backgroundColor: AppColors.primary,
          label: 'Create Account',
          loading: _busy,
          onPressed: _submit,
        ),
        const SizedBox(height: 12),
        Text(
          'For adults 18+. By continuing you agree to our Terms of Service and Community Guidelines.',
          textAlign: TextAlign.center,
          style: t.textTheme.bodySmall?.copyWith(color: context.inkMuted),
        ),
      ],
    );
  }
}
