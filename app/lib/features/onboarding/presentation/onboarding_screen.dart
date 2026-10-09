import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/config/map_config.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/app_exception.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/form_field.dart';
import '../../../core/widgets/interest_chip.dart';
import '../../../core/widgets/primary_button.dart';
import '../../auth/application/session_controller.dart';
import '../../profile/data/user_profile.dart';

const kPreferenceOptions = <String, String>{
  'small_groups': 'Small groups',
  'big_groups': 'Bigger groups',
  'daytime': 'Daytime',
  'evenings': 'Evenings',
  'weekends': 'Weekends',
  'free_only': 'Free plans',
};

/// Three-step onboarding: about you → city & bio → interests.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _step1 = GlobalKey<FormState>();
  final _step2 = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _bio = TextEditingController();
  final _dobText = TextEditingController();
  DateTime? _dob;
  String? _dobError;
  String _city = MapConfig.cities.first.id;
  final _interests = <String>{};
  final _prefs = <String>{};
  int _step = 0;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final u = context.read<SessionController>().user;
    _name.text = u?.displayName ?? '';
  }

  @override
  void dispose() {
    _name.dispose();
    _bio.dispose();
    _dobText.dispose();
    super.dispose();
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 25, now.month, now.day),
      firstDate: DateTime(now.year - 100),
      lastDate: now,
      helpText: 'Date of birth',
    );
    if (picked != null) {
      setState(() {
        _dob = picked;
        _dobText.text = DateFormat.yMMMMd().format(picked);
        _dobError = Validators.dateOfBirth(picked);
      });
    }
  }

  void _next() {
    if (_step == 0) {
      final ok = _step1.currentState!.validate();
      final dobErr = Validators.dateOfBirth(_dob);
      setState(() => _dobError = dobErr);
      if (!ok || dobErr != null) return;
    } else if (_step == 1) {
      if (!_step2.currentState!.validate()) return;
    }
    setState(() => _step++);
  }

  Future<void> _finish() async {
    if (_interests.isEmpty) {
      setState(
        () => _error = 'Pick at least one interest so we can suggest plans.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<SessionController>().completeOnboarding(
        displayName: _name.text,
        dateOfBirth: _dob!,
        city: _city,
        bio: _bio.text,
        interests: _interests.toList(),
        preferredActivityTypes: _prefs.toList(),
        photoUrl: context.read<SessionController>().user?.photoUrl,
      );
    } on AppException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _step--);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('Step ${_step + 1} of 3'),
          leading: _step == 0
              ? null
              : IconButton(
                  tooltip: 'Back',
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => setState(() => _step--),
                ),
          actions: [
            TextButton(
              onPressed: () => context.read<SessionController>().signOut(),
              child: const Text('Sign out'),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(4),
            child: LinearProgressIndicator(value: (_step + 1) / 3),
          ),
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: SingleChildScrollView(
                padding: AppSpacing.page.copyWith(top: 24, bottom: 24),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: AnimatedSwitcher(
                  duration: AppMotion.normal,
                  child: KeyedSubtree(
                    key: ValueKey(_step),
                    child: _buildStep(t),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStep(ThemeData t) {
    switch (_step) {
      case 0:
        return Form(
          key: _step1,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Let\'s get you set up', style: t.textTheme.headlineMedium),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Your name is shown to other members.',
                style: t.textTheme.bodyLarge?.copyWith(
                  color: t.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              AppFormField(
                label: 'Display name',
                controller: _name,
                validator: Validators.displayName,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.givenName],
              ),
              const SizedBox(height: AppSpacing.lg),
              TextFormField(
                controller: _dobText,
                readOnly: true,
                onTap: _pickDob,
                decoration: InputDecoration(
                  labelText: 'Date of birth',
                  helperText:
                      'You must be 18 or older. Never shown on your profile.',
                  errorText: _dobError,
                  suffixIcon: const Icon(Icons.calendar_today_outlined),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              PrimaryButton(label: 'Continue', onPressed: _next),
            ],
          ),
        );
      case 1:
        return Form(
          key: _step2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Where are you based?', style: t.textTheme.headlineMedium),
              const SizedBox(height: AppSpacing.lg),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final c in MapConfig.cities)
                    ChoiceChip(
                      label: Text(c.name),
                      selected: _city == c.id,
                      onSelected: (_) => setState(() => _city = c.id),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'This sets your starting map view. We only use your device location if you allow it, and never share it.',
                style: t.textTheme.bodySmall?.copyWith(
                  color: t.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              AppFormField(
                label: 'Short bio (optional)',
                controller: _bio,
                validator: Validators.bio,
                maxLines: 4,
                maxLength: 300,
              ),
              const SizedBox(height: AppSpacing.lg),
              PrimaryButton(label: 'Continue', onPressed: _next),
            ],
          ),
        );
      default:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('What are you into?', style: t.textTheme.headlineMedium),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Pick a few. You can change these anytime.',
              style: t.textTheme.bodyLarge?.copyWith(
                color: t.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final i in kInterests)
                  InterestChip(
                    interestId: i.id,
                    selected: _interests.contains(i.id),
                    onSelected: (v) => setState(
                      () => v ? _interests.add(i.id) : _interests.remove(i.id),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            Text('Plans you prefer', style: t.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final e in kPreferenceOptions.entries)
                  FilterChip(
                    label: Text(e.value),
                    selected: _prefs.contains(e.key),
                    showCheckmark: false,
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
            PrimaryButton(label: 'Finish', loading: _busy, onPressed: _finish),
          ],
        );
    }
  }
}
