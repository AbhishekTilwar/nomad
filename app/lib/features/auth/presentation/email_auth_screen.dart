import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/form_field.dart';
import '../../../core/widgets/primary_button.dart';
import '../data/auth_repository.dart';
import 'google_sign_in_button.dart';

/// Email sign-in and registration share one screen.
class EmailAuthScreen extends StatefulWidget {
  const EmailAuthScreen({super.key, this.register = false});
  final bool register;

  @override
  State<EmailAuthScreen> createState() => _EmailAuthScreenState();
}

class _EmailAuthScreenState extends State<EmailAuthScreen> {
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
    final auth = context.read<AuthRepository>();
    try {
      if (widget.register) {
        await auth.registerWithEmail(_email.text, _password.text);
      } else {
        await auth.signInWithEmail(_email.text, _password.text);
      }
      // Router reacts to the session change; nothing else to do here.
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final reg = widget.register;
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: AppSpacing.page,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _form,
                child: AutofillGroup(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        reg ? 'Create your account' : 'Welcome back',
                        style: t.textTheme.headlineMedium,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        reg
                            ? 'We\'ll email you a link to verify your address.'
                            : 'Sign in to see what\'s happening near you.',
                        style: t.textTheme.bodyLarge?.copyWith(
                          color: t.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      AppFormField(
                        label: 'Email',
                        controller: _email,
                        validator: Validators.email,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.email],
                        prefixIcon: Icons.mail_outline,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      AppFormField(
                        label: 'Password',
                        controller: _password,
                        obscure: true,
                        validator: reg
                            ? Validators.password
                            : (v) => (v == null || v.isEmpty)
                                  ? 'Enter your password.'
                                  : null,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _submit(),
                        autofillHints: [
                          reg
                              ? AutofillHints.newPassword
                              : AutofillHints.password,
                        ],
                        prefixIcon: Icons.lock_outline,
                      ),
                      if (!reg)
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => context.push('/forgot-password'),
                            child: const Text('Forgot password?'),
                          ),
                        ),
                      if (_error != null) ...[
                        const SizedBox(height: AppSpacing.md),
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            _error!,
                            style: TextStyle(color: t.colorScheme.error),
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.xl),
                      PrimaryButton(
                        label: reg ? 'Create account' : 'Sign in',
                        loading: _busy,
                        onPressed: _submit,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Row(
                        children: [
                          const Expanded(child: Divider()),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              'Or continue with',
                              style: t.textTheme.bodySmall?.copyWith(
                                color: t.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          const Expanded(child: Divider()),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      const GoogleSignInButton(),
                      const SizedBox(height: AppSpacing.md),
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () => reg
                                  ? context.pop()
                                  : context.pushReplacement('/register'),
                        child: Text(
                          reg
                              ? 'I already have an account'
                              : 'New here? Create an account',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
