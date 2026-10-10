import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/config/map_config.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/app_exception.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/brand_logo.dart';
import '../../../core/widgets/form_field.dart';
import '../../../core/widgets/app_chip.dart';
import '../../../core/widgets/primary_button.dart';
import '../../auth/application/session_controller.dart';
import 'dob_field.dart';
import 'interest_picker.dart';

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
  DateTime? _dob;
  String? _city;
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
    super.dispose();
  }

  void _next() {
    if (_step == 0) {
      if (!_step1.currentState!.validate()) return;
    } else if (_step == 1) {
      if (!_step2.currentState!.validate()) return;
    }
    setState(() => _step++);
  }

  Future<void> _finish() async {
    if (_interests.length < kMinInterests) {
      setState(
        () => _error =
            'Choose at least $kMinInterests interests so we can suggest plans.',
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
        city: _city!,
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
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                children: [
                  SizedBox(
                    height: 48,
                    child: Row(
                      children: [
                        const SizedBox(width: 12),
                        if (_step == 0)
                          const SizedBox(width: 48)
                        else
                          IconButton(
                            tooltip: 'Back',
                            icon: const Icon(
                              Icons.arrow_back_ios_new,
                              size: 20,
                            ),
                            onPressed: () => setState(() => _step--),
                          ),
                        Expanded(
                          child: Text(
                            'Step ${_step + 1} of 3',
                            textAlign: TextAlign.center,
                            style: t.textTheme.labelMedium?.copyWith(
                              color: AppColors.inkMuted,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () =>
                              context.read<SessionController>().signOut(),
                          child: const Text('Sign out'),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (_step + 1) / 3,
                        minHeight: 6,
                        backgroundColor: AppColors.tint,
                        color: AppColors.navy,
                      ),
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Center(child: BrandLogo(size: 28)),
                          const SizedBox(height: 20),
                          AnimatedSwitcher(
                            duration: AppMotion.normal,
                            child: KeyedSubtree(
                              key: ValueKey(_step),
                              child: _buildStep(t),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _heading(ThemeData t, String title, [String? sub]) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: t.textTheme.headlineMedium),
      if (sub != null) ...[
        const SizedBox(height: 6),
        Text(
          sub,
          style: t.textTheme.bodyMedium?.copyWith(color: AppColors.inkMuted),
        ),
      ],
      const SizedBox(height: 28),
    ],
  );

  Widget _buildStep(ThemeData t) {
    switch (_step) {
      case 0:
        return Form(
          key: _step1,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _heading(
                t,
                'Let\'s get you set up',
                'Your name is shown to other members.',
              ),
              AppFormField(
                label: 'Display name',
                showLabel: false,
                controller: _name,
                validator: Validators.displayName,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.givenName],
                prefixIcon: Icons.person_outline,
              ),
              const SizedBox(height: 12),
              DobFormField(onChanged: (d) => _dob = d),
              const SizedBox(height: 8),
              Text(
                'You must be 18 or older. Never shown on your profile.',
                style: t.textTheme.bodySmall?.copyWith(
                  color: AppColors.inkMuted,
                ),
              ),
              const SizedBox(height: 24),
              PrimaryButton(
                backgroundColor: AppColors.navy,
                label: 'Continue',
                onPressed: _next,
              ),
            ],
          ),
        );
      case 1:
        return Form(
          key: _step2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _heading(
                t,
                'Where are you based?',
                'This sets your starting map view. We only use your device location if you allow it, and never share it.',
              ),
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
              const SizedBox(height: 12),
              AppFormField(
                label: 'Short bio (optional)',
                showLabel: false,
                hint: 'Short bio (optional)',
                controller: _bio,
                validator: Validators.bio,
                maxLines: 4,
                maxLength: 300,
              ),
              const SizedBox(height: 12),
              PrimaryButton(
                backgroundColor: AppColors.navy,
                label: 'Continue',
                onPressed: _next,
              ),
            ],
          ),
        );
      default:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _heading(
              t,
              'What are you into?',
              'Pick a few. You can change these anytime.',
            ),
            const InterestsHeader(),
            const SizedBox(height: 10),
            InterestPicker(
              selected: _interests,
              onToggle: (id, on) => setState(
                () => on ? _interests.add(id) : _interests.remove(id),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Plans you prefer',
              style: t.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 10,
              children: [
                for (final e in kPreferenceOptions.entries)
                  AppChip(
                    label: e.value,
                    selected: _prefs.contains(e.key),
                    style: AppChipStyle.tinted,
                    onSelected: (v) => setState(
                      () => v ? _prefs.add(e.key) : _prefs.remove(e.key),
                    ),
                  ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Semantics(
                liveRegion: true,
                child: Text(
                  _error!,
                  style: TextStyle(color: t.colorScheme.error),
                ),
              ),
            ],
            const SizedBox(height: 24),
            PrimaryButton(
              backgroundColor: AppColors.navy,
              label: 'Finish',
              loading: _busy,
              onPressed: _finish,
            ),
          ],
        );
    }
  }
}
