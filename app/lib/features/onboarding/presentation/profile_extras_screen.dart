import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/config/map_config.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/app_exception.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/primary_button.dart';
import '../../auth/application/session_controller.dart';
import 'onboarding_widgets.dart';

/// Optional last step after the photo: a short story (bio + Instagram).
/// Skippable. Also saves the country implied by the chosen city, so location
/// is only asked once.
class ProfileExtrasScreen extends StatefulWidget {
  const ProfileExtrasScreen({super.key});

  @override
  State<ProfileExtrasScreen> createState() => _ProfileExtrasScreenState();
}

class _ProfileExtrasScreenState extends State<ProfileExtrasScreen> {
  static final _handle = RegExp(r'^[A-Za-z0-9._]{1,30}$');

  final _bio = TextEditingController();
  final _instagram = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _bio.dispose();
    _instagram.dispose();
    super.dispose();
  }

  String get _handleText => _instagram.text.replaceFirst('@', '').trim();

  String? get _instagramError =>
      _handleText.isEmpty || _handle.hasMatch(_handleText)
      ? null
      : 'Use letters, numbers, dots and underscores only.';

  bool get _valid =>
      Validators.bio(_bio.text) == null && _instagramError == null;

  Future<void> _finish({required bool keepStory}) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final session = context.read<SessionController>();
    final profile = session.profile;
    final bio = keepStory ? _bio.text.trim() : '';
    final handle = keepStory ? _handleText : '';
    // The city already tells us the country; don't ask for it again.
    final country = (profile?.countryCode ?? '').isEmpty && profile != null
        ? MapConfig.cityById(profile.city).countryCode
        : null;
    try {
      if (bio.isNotEmpty || handle.isNotEmpty || country != null) {
        await session.updateProfile(
          bio: bio.isEmpty ? null : bio,
          instagram: handle.isEmpty ? null : handle,
          countryCode: country,
        );
      }
      session.finishProfileExtras();
    } on AppException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return OnboardingFrame(
      progress: 1,
      title: 'Tell your story',
      subtitle: 'Add a bio and a social link to help others connect with you.',
      badge: Icons.edit_note_outlined,
      trailing: TextButton(
        onPressed: _busy ? null : () => _finish(keepStory: false),
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
                  style: TextStyle(color: t.colorScheme.error),
                ),
              ),
            ),
          PrimaryButton(
            label: 'Finish',
            loading: _busy,
            onPressed: _valid ? () => _finish(keepStory: true) : null,
          ),
        ],
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const FieldCaption('Bio'),
            TextField(
              controller: _bio,
              maxLines: 5,
              minLines: 4,
              maxLength: 300,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'What do you love doing? Share a bit about yourself.',
                helperText: 'Express yourself authentically',
                errorText: Validators.bio(_bio.text),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            const FieldCaption('Social link'),
            Text(
              'Add one social media profile to build trust.',
              style: t.textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _instagram,
              keyboardType: TextInputType.text,
              autocorrect: false,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'username',
                prefixIcon: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.camera_alt_outlined, color: AppColors.ink),
                      SizedBox(width: 8),
                      Text('@', style: TextStyle(color: AppColors.inkMuted)),
                    ],
                  ),
                ),
                errorText: _instagramError,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
