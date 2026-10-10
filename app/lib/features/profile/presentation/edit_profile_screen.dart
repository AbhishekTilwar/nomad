import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/config/map_config.dart';
import '../../../core/utils/countries.dart';
import '../../../core/services/image_upload_service.dart';
import '../../../core/widgets/photo_source_sheet.dart';
import '../../../core/widgets/user_avatar.dart';
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
  late final TextEditingController _instagram;
  String _country = '';
  late List<String> _photos;
  bool _uploadingGallery = false;
  static const _maxPhotos = 6;
  late String _city;
  late final Set<String> _interests;
  late final Set<String> _prefs;
  bool _busy = false;
  bool _uploading = false;
  String? _error;

  /// Newly uploaded photo URL (sent on Save) / whether to clear the photo.
  String? _newPhotoUrl;
  bool _removePhoto = false;

  @override
  void initState() {
    super.initState();
    final p = context.read<SessionController>().profile!;
    _name = TextEditingController(text: p.displayName);
    _bio = TextEditingController(text: p.bio);
    _instagram = TextEditingController(text: p.instagram ?? '');
    _country = p.countryCode ?? '';
    _photos = [...p.photos];
    _city = p.city;
    _interests = {...p.interests};
    _prefs = {...p.preferredActivityTypes};
  }

  @override
  void dispose() {
    _name.dispose();
    _bio.dispose();
    _instagram.dispose();
    super.dispose();
  }

  String? get _shownPhoto => _removePhoto
      ? null
      : (_newPhotoUrl ?? context.read<SessionController>().profile?.photoUrl);

  /// Picks, compresses (max 512px, JPEG 80) and uploads to Firebase Storage
  /// under users/{uid}/avatar/. Only uploads when the user picks a photo.
  Future<void> _pickPhoto() async {
    final uid = context.read<SessionController>().user?.uid;
    if (uid == null || _uploading) return;
    final images = context.read<ImageUploadService>();
    final source = await PhotoSourceSheet.show(context);
    if (source == null || !mounted) return;
    setState(() {
      _uploading = true;
      _error = null;
    });
    try {
      final url = await images.pickAndUpload(
        uid,
        ImageKind.avatar,
        camera: source == PhotoSource.camera,
      );
      if (url != null && mounted) {
        setState(() {
          _newPhotoUrl = url;
          _removePhoto = false;
        });
      }
    } on AppException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _addGalleryPhoto() async {
    final uid = context.read<SessionController>().user?.uid;
    if (uid == null || _uploadingGallery || _photos.length >= _maxPhotos) {
      return;
    }
    final images = context.read<ImageUploadService>();
    final source = await PhotoSourceSheet.show(context);
    if (source == null || !mounted) return;
    setState(() {
      _uploadingGallery = true;
      _error = null;
    });
    try {
      final url = await images.pickAndUpload(
        uid,
        ImageKind.gallery,
        camera: source == PhotoSource.camera,
      );
      if (url != null && mounted) setState(() => _photos.add(url));
    } on AppException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _uploadingGallery = false);
    }
  }

  Widget _photoGrid(ThemeData t) {
    Widget tile(int i) => Stack(
      key: ValueKey('edit-photo-$i'),
      fit: StackFit.expand,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: CachedNetworkImage(
            imageUrl: _photos[i],
            fit: BoxFit.cover,
            memCacheWidth: 300,
          ),
        ),
        if (i == 0)
          Positioned(
            left: 6,
            bottom: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'Cover',
                style: TextStyle(color: Colors.white, fontSize: 11),
              ),
            ),
          )
        else
          Positioned(
            left: 2,
            bottom: 2,
            child: IconButton(
              tooltip: 'Make cover photo',
              iconSize: 18,
              visualDensity: VisualDensity.compact,
              style: IconButton.styleFrom(backgroundColor: Colors.black54),
              color: Colors.white,
              icon: const Icon(Icons.star_outline),
              onPressed: () => setState(() {
                final u = _photos.removeAt(i);
                _photos.insert(0, u);
              }),
            ),
          ),
        Positioned(
          right: 2,
          top: 2,
          child: IconButton(
            tooltip: 'Remove photo',
            iconSize: 18,
            visualDensity: VisualDensity.compact,
            style: IconButton.styleFrom(backgroundColor: Colors.black54),
            color: Colors.white,
            icon: const Icon(Icons.close),
            onPressed: () => setState(() => _photos.removeAt(i)),
          ),
        ),
      ],
    );

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 0.8,
      children: [
        for (var i = 0; i < _photos.length; i++) tile(i),
        if (_photos.length < _maxPhotos)
          InkWell(
            key: const ValueKey('add-gallery-photo'),
            borderRadius: BorderRadius.circular(AppRadius.md),
            onTap: _uploadingGallery ? null : _addGalleryPhoto,
            child: Ink(
              decoration: BoxDecoration(
                color: AppColors.field,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.outline),
              ),
              child: Center(
                child: _uploadingGallery
                    ? const CircularProgressIndicator(strokeWidth: 2)
                    : Icon(
                        Icons.add_a_photo_outlined,
                        color: t.colorScheme.primary,
                      ),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    if (_shownPhoto == null && _photos.isEmpty) {
      setState(() => _error = 'Add at least one photo.');
      return;
    }
    if (_interests.isEmpty) {
      setState(() => _error = 'Pick at least one interest.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final current = context.read<SessionController>().profile!;
    final newInstagram = _instagram.text.replaceFirst('@', '').trim();
    // Only send the newer fields when they changed, so ordinary edits keep
    // working against an API that predates them.
    final countryChanged = _country != (current.countryCode ?? '');
    final instagramChanged = newInstagram != (current.instagram ?? '');
    final photosChanged = !listEquals(_photos, current.photos);
    try {
      await context.read<SessionController>().updateProfile(
        displayName: _name.text,
        bio: _bio.text,
        city: _city,
        interests: _interests.toList(),
        preferredActivityTypes: _prefs.toList(),
        photoUrl: _newPhotoUrl,
        removePhoto: _removePhoto,
        countryCode: countryChanged ? _country : null,
        instagram: instagramChanged ? newInstagram : null,
        photos: photosChanged ? _photos : null,
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
              Center(
                child: Column(
                  children: [
                    Stack(
                      children: [
                        UserAvatar(
                          name: _name.text.isEmpty ? '?' : _name.text,
                          photoUrl: _shownPhoto,
                          size: 96,
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Material(
                            color: t.colorScheme.primary,
                            shape: const CircleBorder(
                              side: BorderSide(color: Colors.white, width: 2),
                            ),
                            child: IconButton(
                              tooltip: 'Change profile photo',
                              iconSize: 18,
                              color: Colors.white,
                              onPressed: _uploading ? null : _pickPhoto,
                              icon: _uploading
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.photo_camera_outlined),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_shownPhoto != null && _photos.isNotEmpty)
                      TextButton(
                        onPressed: () => setState(() {
                          _removePhoto = true;
                          _newPhotoUrl = null;
                        }),
                        child: const Text('Remove photo'),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text('Photos', style: t.textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                'Add up to $_maxPhotos photos so people can get to know you. '
                'The first one is your cover.',
                style: t.textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.sm),
              _photoGrid(t),
              const SizedBox(height: AppSpacing.lg),
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
              const SizedBox(height: AppSpacing.lg),
              AppFormField(
                label: 'Instagram',
                controller: _instagram,
                hint: '@yourhandle',
                prefixIcon: Icons.alternate_email,
                validator: (v) {
                  final h = (v ?? '').trim().replaceFirst('@', '');
                  if (h.isEmpty) return null;
                  return RegExp(r'^[A-Za-z0-9._]{1,30}$').hasMatch(h)
                      ? null
                      : 'Letters, numbers, . and _ only';
                },
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('Country', style: t.textTheme.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              DropdownButtonFormField<String>(
                initialValue: kCountries.containsKey(_country) ? _country : '',
                isExpanded: true,
                decoration: const InputDecoration(
                  hintText: 'Where are you from?',
                ),
                items: [
                  const DropdownMenuItem(value: '', child: Text('Not shown')),
                  for (final e in kCountries.entries)
                    DropdownMenuItem(
                      value: e.key,
                      child: Text('${flagEmoji(e.key)}  ${e.value}'),
                    ),
                ],
                onChanged: (v) => setState(() => _country = v ?? ''),
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
