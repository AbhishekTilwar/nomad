import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/services/image_upload_service.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/app_exception.dart';
import '../../../core/widgets/photo_source_sheet.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/secondary_button.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../auth/application/session_controller.dart';

/// Shown once right after profile setup: take or choose a profile photo
/// (optional; Skip is always available).
class AddPhotoScreen extends StatefulWidget {
  const AddPhotoScreen({super.key});

  @override
  State<AddPhotoScreen> createState() => _AddPhotoScreenState();
}

class _AddPhotoScreenState extends State<AddPhotoScreen> {
  String? _uploadedUrl;
  bool _busy = false;
  String? _error;

  Future<void> _pick(PhotoSource source) async {
    final session = context.read<SessionController>();
    final uid = session.user?.uid;
    if (uid == null || _busy) return;
    final images = context.read<ImageUploadService>();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final url = await images.pickAndUpload(
        uid,
        ImageKind.avatar,
        camera: source == PhotoSource.camera,
      );
      if (url != null) {
        await session.updateProfile(photoUrl: url);
        if (mounted) setState(() => _uploadedUrl = url);
      }
    } on AppException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _choose() async {
    final source = await PhotoSourceSheet.show(context);
    if (source != null && mounted) await _pick(source);
  }

  Future<void> _done() async {
    final session = context.read<SessionController>();
    session.finishPhotoPrompt();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final session = context.watch<SessionController>();
    final name = session.profile?.displayName ?? '';
    final has = _uploadedUrl != null;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _busy ? null : _done,
                      child: Text(has ? 'Done' : 'Skip'),
                    ),
                  ),
                  const Spacer(),
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      UserAvatar(
                        name: name.isEmpty ? '?' : name,
                        photoUrl: _uploadedUrl,
                        size: 160,
                      ),
                      if (_busy)
                        const Positioned.fill(
                          child: Center(child: CircularProgressIndicator()),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    has ? 'Looking good!' : 'Add a profile photo',
                    style: t.textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    has
                        ? 'Your photo shows on your plans and in chats.'
                        : 'People are more likely to say yes when they can see who they\'re meeting. Use a clear photo of your face.',
                    style: t.textTheme.bodyLarge?.copyWith(
                      color: t.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        _error!,
                        style: TextStyle(color: t.colorScheme.error),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                  const Spacer(flex: 2),
                  if (has)
                    PrimaryButton(label: 'Continue', onPressed: _done)
                  else ...[
                    PrimaryButton(
                      label: 'Take photo',
                      icon: Icons.photo_camera_outlined,
                      loading: _busy,
                      onPressed: () => _pick(PhotoSource.camera),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    SecondaryButton(
                      label: 'Choose from gallery',
                      icon: Icons.photo_library_outlined,
                      onPressed: _busy
                          ? null
                          : () => _pick(PhotoSource.gallery),
                    ),
                  ],
                  if (has)
                    TextButton(
                      onPressed: _busy ? null : _choose,
                      child: const Text('Change photo'),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
