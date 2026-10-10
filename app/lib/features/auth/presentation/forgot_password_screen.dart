import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/form_field.dart';
import '../../../core/widgets/primary_button.dart';
import '../data/auth_repository.dart';
import 'auth_layout.dart';

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
    if (_sent) {
      return AuthPage(
        title: 'Check your inbox',
        subtitle:
            'If an account exists for that address, we\'ve sent a link to reset your password.',
        children: [
          const SizedBox(height: 8),
          Icon(
            Icons.mark_email_read_outlined,
            size: 56,
            color: t.colorScheme.primary,
          ),
        ],
      );
    }
    return AuthPage(
      title: 'Reset Password',
      subtitle: 'Enter your email and we\'ll send you a reset link.',
      children: [
        Form(
          key: _form,
          child: AppFormField(
            label: 'Email',
            showLabel: false,
            controller: _email,
            validator: Validators.email,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.email],
            prefixIcon: Icons.mail_outline,
            onSubmitted: (_) => _submit(),
          ),
        ),
        if (_error != null) ...[const SizedBox(height: 12), AuthError(_error!)],
        const SizedBox(height: 24),
        PrimaryButton(
          backgroundColor: AppColors.navy,
          label: 'Send reset link',
          loading: _busy,
          onPressed: _submit,
        ),
      ],
    );
  }
}
