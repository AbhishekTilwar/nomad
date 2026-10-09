import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/utils/validators.dart';
import '../../../core/widgets/form_field.dart';
import '../../../core/widgets/primary_button.dart';
import '../data/auth_repository.dart';
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
      title: 'Welcome Back',
      subtitle: 'Login to continue',
      footer: AuthSwitchRow(
        prompt: 'Don\'t have an account?',
        action: 'Sign Up',
        onPressed: _busy ? null : () => context.pushReplacement('/register'),
      ),
      children: [
        Form(
          key: _form,
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppFormField(
                  label: 'Email',
                  showLabel: false,
                  controller: _email,
                  validator: Validators.email,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email],
                  prefixIcon: Icons.mail_outline,
                ),
                const SizedBox(height: 14),
                AppFormField(
                  label: 'Password',
                  showLabel: false,
                  controller: _password,
                  obscure: true,
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Enter your password.' : null,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                  autofillHints: const [AutofillHints.password],
                  prefixIcon: Icons.lock_outline,
                ),
              ],
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            style: TextButton.styleFrom(
              minimumSize: const Size(0, 44),
              padding: const EdgeInsets.symmetric(horizontal: 4),
            ),
            onPressed: () => context.push('/forgot-password'),
            child: const Text('Forgot password?'),
          ),
        ),
        if (_error != null) ...[AuthError(_error!), const SizedBox(height: 12)],
        const SizedBox(height: 4),
        PrimaryButton(label: 'Login', loading: _busy, onPressed: _submit),
        const SizedBox(height: 24),
        const OrContinueWith(),
        const SizedBox(height: 14),
        const GoogleSignInButton(),
      ],
    );
  }
}
