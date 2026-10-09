import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/config/map_config.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/form_field.dart';
import '../../../core/widgets/primary_button.dart';
import '../../onboarding/presentation/dob_field.dart';
import '../../onboarding/presentation/interest_picker.dart';
import '../application/signup_draft.dart';
import '../data/auth_repository.dart';
import 'auth_layout.dart';

/// Email registration that also collects the profile basics, so onboarding
/// can be skipped once the email is verified.
class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key, this.drafts = const SignupDraftStore()});

  final SignupDraftStore drafts;

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  DateTime? _dob;
  String? _city;
  final _interests = <String>{};
  bool _interestsError = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    final ok = _form.currentState!.validate();
    final enough = _interests.length >= kMinInterests;
    setState(() => _interestsError = !enough);
    if (!ok || !enough) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final auth = context.read<AuthRepository>();
    try {
      await widget.drafts.save(
        SignupDraft(
          name: _name.text.trim(),
          dateOfBirth: _dob!,
          city: _city!,
          interests: _interests.toList(),
        ),
      );
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
      subtitle: 'Let\'s set up your profile',
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
                AppFormField(
                  label: 'Name',
                  showLabel: false,
                  controller: _name,
                  validator: Validators.displayName,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.name],
                  prefixIcon: Icons.person_outline,
                ),
                const SizedBox(height: 12),
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
                const SizedBox(height: 12),
                AppFormField(
                  label: 'Password',
                  showLabel: false,
                  controller: _password,
                  obscure: true,
                  validator: Validators.password,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.newPassword],
                  prefixIcon: Icons.lock_outline,
                ),
                const SizedBox(height: 12),
                DobFormField(onChanged: (d) => _dob = d),
                const SizedBox(height: 12),
                AppDropdownField<String>(
                  label: 'Select Location',
                  showLabel: false,
                  prefixIcon: Icons.location_on_outlined,
                  value: _city,
                  validator: (v) => v == null ? 'Select your city.' : null,
                  items: [
                    for (final c in MapConfig.cities)
                      DropdownMenuItem(value: c.id, child: Text(c.name)),
                  ],
                  onChanged: (v) => setState(() => _city = v),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        const InterestsHeader(),
        const SizedBox(height: 10),
        InterestPicker(
          selected: _interests,
          onToggle: (id, on) => setState(() {
            on ? _interests.add(id) : _interests.remove(id);
            if (_interests.length >= kMinInterests) _interestsError = false;
          }),
        ),
        if (_interestsError) ...[
          const SizedBox(height: 8),
          Semantics(
            liveRegion: true,
            child: Text(
              'Choose at least $kMinInterests interests.',
              style: t.textTheme.bodySmall?.copyWith(color: AppColors.danger),
            ),
          ),
        ],
        if (_error != null) ...[const SizedBox(height: 12), AuthError(_error!)],
        const SizedBox(height: 20),
        PrimaryButton(
          label: 'Create Account',
          loading: _busy,
          onPressed: _submit,
        ),
        const SizedBox(height: 12),
        Text(
          'For adults 18+. By continuing you agree to our Terms of Service and Community Guidelines.',
          textAlign: TextAlign.center,
          style: t.textTheme.bodySmall?.copyWith(color: AppColors.inkMuted),
        ),
      ],
    );
  }
}
