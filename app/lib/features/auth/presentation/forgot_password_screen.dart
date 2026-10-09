import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/form_field.dart';
import '../../../core/widgets/primary_button.dart';
import '../data/auth_repository.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _busy = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<AuthRepository>().sendPasswordReset(_email.text);
      if (mounted) setState(() => _sent = true);
    } on AuthFailure catch (e) {
      // user-not-found is treated as success to avoid revealing which emails exist.
      if (mounted) {
        setState(() {
          if (e.code == 'user-not-found') {
            _sent = true;
          } else {
            _error = e.message;
          }
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Reset password')),
      body: SafeArea(
        child: Padding(
          padding: AppSpacing.page,
          child: _sent
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.mark_email_read_outlined, size: 56),
                    const SizedBox(height: AppSpacing.lg),
                    Text('Check your inbox', style: t.textTheme.titleLarge),
                    const SizedBox(height: AppSpacing.sm),
                    const Text(
                      'If an account exists for that address, we\'ve sent a link to reset your password.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                )
              : Form(
                  key: _form,
                  child: ListView(
                    children: [
                      const SizedBox(height: AppSpacing.lg),
                      const Text(
                        'Enter your email and we\'ll send you a reset link.',
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      AppFormField(
                        label: 'Email',
                        controller: _email,
                        validator: Validators.email,
                        keyboardType: TextInputType.emailAddress,
                        onSubmitted: (_) => _submit(),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          _error!,
                          style: TextStyle(color: t.colorScheme.error),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.xl),
                      PrimaryButton(
                        label: 'Send reset link',
                        loading: _busy,
                        onPressed: _submit,
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
