import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/config/map_config.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/app_exception.dart';
import '../../../core/utils/category_style.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_chip.dart';
import '../../../core/widgets/primary_button.dart';
import '../../auth/application/session_controller.dart';
import '../../profile/data/user_profile.dart';
import 'onboarding_widgets.dart';

const kPreferenceOptions = <String, String>{
  'small_groups': 'Small groups',
  'big_groups': 'Bigger groups',
  'daytime': 'Daytime',
  'evenings': 'Evenings',
  'weekends': 'Weekends',
  'free_only': 'Free plans',
};

const kGenderOptions = <String, String>{
  'male': 'Male',
  'female': 'Female',
  'non_binary': 'Non-binary',
};

/// Most interests a member can pick.
const kMaxInterests = 10;

/// Number of onboarding steps, including the photo and story steps that
/// follow on their own screens.
const kOnboardingSteps = 6;

/// Step-by-step onboarding: name & birthday → gender → city → interests
/// (the photo step follows as its own screen).
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _name = TextEditingController();
  DateTime? _dob;
  String? _gender;
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
    super.dispose();
  }

  bool get _valid => switch (_step) {
    0 =>
      Validators.displayName(_name.text) == null &&
          Validators.dateOfBirth(_dob) == null,
    1 => _gender != null,
    2 => _city != null,
    _ => _interests.isNotEmpty,
  };

  void _back() => setState(() {
    _step--;
    _error = null;
  });

  void _next() {
    FocusScope.of(context).unfocus();
    setState(() => _step++);
  }

  Future<void> _finish() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final session = context.read<SessionController>();
      await session.completeOnboarding(
        displayName: _name.text,
        dateOfBirth: _dob!,
        city: _city!,
        bio: '',
        interests: _interests.toList(),
        preferredActivityTypes: _prefs.toList(),
        gender: _gender,
        photoUrl: session.user?.photoUrl,
      );
    } on AppException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _skipGender() => setState(() {
    _gender = null;
    _step++;
  });

  @override
  Widget build(BuildContext context) {
    final progress = (_step + 1) / kOnboardingSteps;
    final onBack = _step == 0 ? null : _back;
    final Widget frame = switch (_step) {
      0 => OnboardingFrame(
        progress: progress,
        title: 'What should we call you?',
        subtitle: 'Let\'s get your profile started.',
        badge: Icons.waving_hand_outlined,
        trailing: TextButton(
          onPressed: () => context.read<SessionController>().signOut(),
          child: const Text('Sign out'),
        ),
        footer: PrimaryButton(
          label: 'Continue',
          onPressed: _valid ? _next : null,
        ),
        child: _scroll([
          const FieldCaption('Your name'),
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.givenName],
            maxLength: 40,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Your name',
              counterText: '',
              prefixIcon: const Icon(Icons.person_outline),
              suffixIcon: Validators.displayName(_name.text) == null
                  ? const Icon(Icons.check_circle, color: AppColors.success)
                  : null,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          DobPickerTile(
            value: _dob,
            onChanged: (d) => setState(() => _dob = d),
          ),
        ]),
      ),
      1 => OnboardingFrame(
        progress: progress,
        onBack: onBack,
        title: 'What\'s your gender?',
        subtitle: 'Kept private. It is never shown on your profile.',
        badge: Icons.diversity_3_outlined,
        trailing: TextButton(onPressed: _skipGender, child: const Text('Skip')),
        footer: PrimaryButton(
          label: 'Continue',
          onPressed: _valid ? _next : null,
        ),
        child: _scroll([
          for (final e in kGenderOptions.entries) ...[
            ChoiceTile(
              label: e.value,
              selected: _gender == e.key,
              onTap: () => setState(() => _gender = e.key),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ]),
      ),
      2 => OnboardingFrame(
        progress: progress,
        onBack: onBack,
        title: 'Where are you based?',
        subtitle:
            'This sets your starting map view. We only use your device location if you allow it, and never share it.',
        badge: Icons.location_on_outlined,
        footer: PrimaryButton(
          label: 'Continue',
          onPressed: _valid ? _next : null,
        ),
        child: _scroll([
          for (final c in MapConfig.cities) ...[
            ChoiceTile(
              label: c.name,
              selected: _city == c.id,
              onTap: () => setState(() => _city = c.id),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ]),
      ),
      _ => OnboardingFrame(
        progress: progress,
        onBack: onBack,
        title: 'What interests you?',
        subtitle: 'Pick a few so we can suggest the right plans.',
        titleTrailing: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            '${_interests.length}/$kMaxInterests',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: AppColors.inkMuted,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        trailing: TextButton(
          onPressed: _busy ? null : _finish,
          child: const Text('Skip'),
        ),
        footer: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ),
            PrimaryButton(
              label: 'Finish',
              loading: _busy,
              onPressed: _valid ? _finish : null,
            ),
          ],
        ),
        child: _interestsBody(),
      ),
    };
    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: frame,
    );
  }

  Widget _scroll(List<Widget> children) => SingleChildScrollView(
    padding: const EdgeInsets.symmetric(horizontal: 20),
    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    ),
  );

  Widget _interestsBody() {
    final t = Theme.of(context);
    const options = kInterests;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Interests', style: t.textTheme.labelMedium),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: 8,
                  runSpacing: 10,
                  children: [
                    for (final i in options)
                      AppChip(
                        label: CategoryStyle.shortLabels[i.id] ?? i.label,
                        icon: CategoryStyle.icon(i.id),
                        selected: _interests.contains(i.id),
                        style: AppChipStyle.tinted,
                        onSelected: (on) => setState(() {
                          if (!on) {
                            _interests.remove(i.id);
                          } else if (_interests.length < kMaxInterests) {
                            _interests.add(i.id);
                          }
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                Text('Plans you prefer', style: t.textTheme.labelMedium),
                const SizedBox(height: AppSpacing.sm),
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
                const SizedBox(height: AppSpacing.lg),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
