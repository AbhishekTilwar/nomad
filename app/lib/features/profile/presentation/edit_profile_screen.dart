import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/config/map_config.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/app_exception.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_chip.dart';
import '../../../core/widgets/form_field.dart';
import '../../../core/widgets/interest_chip.dart';
import '../../../core/widgets/primary_button.dart';
import '../../auth/application/session_controller.dart';
import '../data/user_profile.dart';
import '../../onboarding/presentation/onboarding_screen.dart'
    show kPreferenceOptions;

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _bio;
  late String _city;
  late final Set<String> _interests;
  late final Set<String> _prefs;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final p = context.read<SessionController>().profile!;
    _name = TextEditingController(text: p.displayName);
    _bio = TextEditingController(text: p.bio);
    _city = p.city;
    _interests = {...p.interests};
    _prefs = {...p.preferredActivityTypes};
  }

  @override
  void dispose() {
    _name.dispose();
    _bio.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    if (_interests.isEmpty) {
      setState(() => _error = 'Pick at least one interest.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<SessionController>().updateProfile(
        displayName: _name.text,
        bio: _bio.text,
        city: _city,
        interests: _interests.toList(),
        preferredActivityTypes: _prefs.toList(),
      );
      if (mounted) context.pop();
    } on AppException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: AppSpacing.page.copyWith(top: 8, bottom: 24),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            children: [
              AppFormField(
                label: 'Display name',
                controller: _name,
                validator: Validators.displayName,
              ),
              const SizedBox(height: AppSpacing.lg),
              AppFormField(
                label: 'Bio',
                controller: _bio,
                validator: Validators.bio,
                maxLines: 4,
                maxLength: 300,
              ),
              const SizedBox(height: AppSpacing.md),
              Text('City', style: t.textTheme.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final c in MapConfig.cities)
                    AppChip(
                      label: c.name,
                      selected: _city == c.id,
                      onSelected: (_) => setState(() => _city = c.id),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              Text('Interests', style: t.textTheme.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final i in kInterests)
                    InterestChip(
                      interestId: i.id,
                      selected: _interests.contains(i.id),
                      onSelected: (v) => setState(
                        () =>
                            v ? _interests.add(i.id) : _interests.remove(i.id),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              Text('Plans you prefer', style: t.textTheme.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final e in kPreferenceOptions.entries)
                    AppChip(
                      label: e.value,
                      style: AppChipStyle.tinted,
                      selected: _prefs.contains(e.key),
                      onSelected: (v) => setState(
                        () => v ? _prefs.add(e.key) : _prefs.remove(e.key),
                      ),
                    ),
                ],
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
              PrimaryButton(label: 'Save', loading: _busy, onPressed: _save),
            ],
          ),
        ),
      ),
    );
  }
}
