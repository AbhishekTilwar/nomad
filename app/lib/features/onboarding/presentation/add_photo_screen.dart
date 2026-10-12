import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/services/image_upload_service.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/app_exception.dart';
import '../../../core/widgets/photo_source_sheet.dart';
import '../../../core/widgets/primary_button.dart';
import '../../auth/application/session_controller.dart';
import 'onboarding_screen.dart' show kOnboardingSteps;
import 'onboarding_widgets.dart';
import '../../../core/theme/theme_colors.dart';

/// Photo step. During onboarding it can be skipped (people should see the
/// product before being asked for a selfie); joining or hosting later asks for
/// one via `ensureProfilePhoto`, which opens this screen as [standalone].
class AddPhotoScreen extends StatefulWidget {
  const AddPhotoScreen({super.key, this.standalone = false});

  /// Opened from a join/host prompt: pops with `true` instead of advancing
  /// onboarding, and there is no Skip.
  final bool standalone;

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
        // The first photo is also the start of the gallery.
        await session.updateProfile(photoUrl: url, photos: [url]);
        if (mounted) setState(() => _uploadedUrl = url);
      }
    } on AppException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _choose() async {
    if (_busy) return;
    final source = await PhotoSourceSheet.show(context);
    if (source != null && mounted) await _pick(source);
  }

  void _done() {
    if (widget.standalone) {
      Navigator.of(context).pop(true);
    } else {
      context.read<SessionController>().finishPhotoPrompt();
    }
  }

  void _skip() => context.read<SessionController>().finishPhotoPrompt();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final has = _uploadedUrl != null;
    return OnboardingFrame(
      progress: widget.standalone ? null : 5 / kOnboardingSteps,
      onBack: widget.standalone ? () => Navigator.of(context).pop(false) : null,
      title: has ? 'Looking good!' : 'Add a profile photo',
      subtitle: has
          ? 'Your photo shows on your plans and in chats.'
          : widget.standalone
          ? 'Hosts and guests like to know who is coming. Use a clear photo of your face.'
          : 'A clear photo helps people know who is coming. You can add it later, but you\'ll need one to join or host a plan.',
      badge: Icons.photo_camera_outlined,
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
          PrimaryButton(label: 'Continue', onPressed: has ? _done : null),
          if (!widget.standalone && !has)
            TextButton(
              style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
              onPressed: _busy ? null : _skip,
              child: const Text('Skip for now'),
            ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Align(
          alignment: Alignment.topCenter,
          child: AspectRatio(
            aspectRatio: 1,
            child: _PhotoTile(url: _uploadedUrl, busy: _busy, onTap: _choose),
          ),
        ),
      ),
    );
  }
}

/// Large square upload target: dashed outline until a photo is set.
class _PhotoTile extends StatelessWidget {
  const _PhotoTile({
    required this.url,
    required this.busy,
    required this.onTap,
  });

  final String? url;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.xl);
    return Semantics(
      button: true,
      label: url == null ? 'Add a profile photo' : 'Change profile photo',
      child: ExcludeSemantics(
        child: InkWell(
          key: const Key('photo-tile'),
          borderRadius: radius,
          onTap: onTap,
          child: CustomPaint(
            foregroundPainter: url == null
                ? _DashedBorderPainter(radius: radius)
                : null,
            child: ClipRRect(
              borderRadius: radius,
              child: ColoredBox(
                color: context.field,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (url != null)
                      Image.network(
                        url!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const _TileIcon(),
                      )
                    else
                      const _TileIcon(),
                    if (busy)
                      const ColoredBox(
                        color: Color(0x66FFFFFF),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TileIcon extends StatelessWidget {
  const _TileIcon();

  @override
  Widget build(BuildContext context) => const Center(
    child: Icon(Icons.add_a_photo_outlined, size: 44, color: AppColors.primary),
  );
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.radius});
  final BorderRadius radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final path = Path()
      ..addRRect(radius.toRRect(Offset.zero & size).deflate(0.75));
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, d + 7), paint);
        d += 12;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) => old.radius != radius;
}
