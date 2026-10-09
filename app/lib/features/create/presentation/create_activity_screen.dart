import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../../core/config/map_config.dart';
import '../../../core/services/image_upload_service.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/app_exception.dart';
import '../../../core/widgets/activity_card.dart';
import '../../../core/widgets/form_field.dart';
import '../../../core/widgets/app_chip.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/secondary_button.dart';
import '../../activities/data/activity_repository.dart';
import '../../activities/models/activity.dart';
import '../../auth/application/session_controller.dart';
import '../../explore/presentation/explore_controller.dart';
import '../../profile/data/user_profile.dart';
import 'create_activity_controller.dart';

class CreateActivityScreen extends StatelessWidget {
  const CreateActivityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.read<SessionController>();
    return ChangeNotifierProvider(
      create: (_) => CreateActivityController(
        context.read<ActivityRepository>(),
        city: session.profile?.city ?? 'mumbai',
      ),
      child: const _CreateView(),
    );
  }
}

class _CreateView extends StatefulWidget {
  const _CreateView();

  @override
  State<_CreateView> createState() => _CreateViewState();
}

class _CreateViewState extends State<_CreateView> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _venue = TextEditingController();
  final _maxMembers = TextEditingController(text: '8');
  final _costDesc = TextEditingController();
  final _safety = TextEditingController();
  final _cancel = TextEditingController();
  final _scroll = ScrollController();
  bool _uploading = false;

  List<TextEditingController> get _all => [
    _title,
    _description,
    _venue,
    _maxMembers,
    _costDesc,
    _safety,
    _cancel,
  ];

  @override
  void dispose() {
    for (final c in _all) {
      c.dispose();
    }
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime(CreateActivityController c) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: c.startAt ?? now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 180)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(
        c.startAt ?? now.add(const Duration(hours: 3)),
      ),
    );
    if (time == null) return;
    c.update(
      () => c.startAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      ),
    );
  }

  Future<void> _pickLocation(CreateActivityController c) async {
    final picked = await context.push<LatLng>(
      '/create/pick-location',
      extra: c.location ?? MapConfig.cityById(c.city).center,
    );
    if (picked != null) c.update(() => c.location = picked);
  }

  Future<void> _pickCover(CreateActivityController c) async {
    final uid = context.read<SessionController>().user?.uid;
    if (uid == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final images = context.read<ImageUploadService>();
    setState(() => _uploading = true);
    try {
      final url = await images.pickAndUpload(uid, ImageKind.cover);
      if (url != null) c.update(() => c.coverImageUrl = url);
    } on AppException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _preview(CreateActivityController c) async {
    FocusScope.of(context).unfocus();
    if (!c.runValidation()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fix the highlighted fields.')),
      );
      _scroll.animateTo(0, duration: AppMotion.normal, curve: Curves.easeOut);
      return;
    }
    final session = context.read<SessionController>();
    final d = c.buildDraft();
    final preview = Activity(
      id: 'preview',
      title: d.title.trim(),
      description: d.description,
      category: d.category,
      hostId: session.user?.uid ?? '',
      hostDisplayName: session.profile?.displayName ?? 'You',
      hostPhotoUrl: session.profile?.photoUrl,
      city: d.city,
      venueName: d.venueName.trim(),
      latitude: d.latitude,
      longitude: d.longitude,
      startAt: d.startAt,
      endAt: d.endAt,
      capacity: d.capacity,
      participantCount: 1,
      costType: d.costType,
      costDescription: d.costDescription,
      coverImageUrl: d.coverImageUrl,
      approvalRequired: d.approvalRequired,
      status: ActivityStatus.scheduled,
      isHost: true,
    );
    final publish = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheet) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Preview', style: Theme.of(sheet).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.md),
            ActivityCard(activity: preview),
            const SizedBox(height: AppSpacing.lg),
            PrimaryButton(
              label: 'Publish plan',
              onPressed: () => Navigator.pop(sheet, true),
            ),
            const SizedBox(height: AppSpacing.sm),
            SecondaryButton(
              label: 'Keep editing',
              onPressed: () => Navigator.pop(sheet, false),
            ),
          ],
        ),
      ),
    );
    if (publish != true || !mounted) return;
    final created = await c.submit();
    if (!mounted) return;
    if (created != null) {
      _resetForm(c);
      final messenger = ScaffoldMessenger.of(context);
      final router = GoRouter.of(context);
      // Show it on the map right away (and refresh from the server).
      context.read<ExploreController>().showPosted(created);
      router.go('/explore');
      messenger.showSnackBar(
        SnackBar(
          content: const Text('Your plan is live on the map!'),
          action: SnackBarAction(
            label: 'View',
            onPressed: () => router.push('/activity/${created.id}'),
          ),
        ),
      );
    } else if (c.submitError != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(c.submitError!)));
    }
  }

  void _resetForm(CreateActivityController c) {
    for (final t in _all) {
      t.clear();
    }
    _maxMembers.text = '8';
    c.update(() {
      c.title = '';
      c.description = '';
      c.category = null;
      c.startAt = null;
      c.venueName = '';
      c.location = null;
      c.capacity = 8;
      c.costType = CostType.free;
      c.costDescription = '';
      c.approvalRequired = false;
      c.isPrivate = false;
      c.safetyNotes = '';
      c.cancellationPolicy = '';
      c.coverImageUrl = null;
      c.errors = const {};
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<CreateActivityController>();
    final t = Theme.of(context);
    final err = c.errors;
    const gap = SizedBox(height: 16);

    Widget section(String s) => Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 10),
      child: Text(s, style: t.textTheme.titleMedium),
    );

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/explore'),
        ),
        title: const Text('Create a Meetup'),
      ),
      body: SafeArea(
        child: ListView(
          controller: _scroll,
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
            AppFormField(
              label: 'Title',
              hint: 'e.g. Weekend Trek to Lonavala',
              controller: _title,
              maxLength: 80,
              onChanged: (v) => c.title = v,
              validator: (_) => err['title'],
              textInputAction: TextInputAction.next,
            ),
            gap,
            AppDropdownField<String>(
              label: 'Category',
              hint: 'Select category',
              value: c.category,
              items: [
                for (final i in kInterests)
                  DropdownMenuItem(value: i.id, child: Text(i.label)),
              ],
              onChanged: (v) => c.update(() => c.category = v),
              validator: (_) => err['category'],
            ),
            gap,
            AppFormField(
              label: 'Date & Time',
              hint: 'Select date & time',
              initialValue: c.startAt == null
                  ? ''
                  : DateFormat('EEE, d MMM · h:mm a').format(c.startAt!),
              readOnly: true,
              onTap: () => _pickDateTime(c),
              suffixIcon: const Icon(Icons.calendar_today_outlined, size: 20),
              validator: (_) => err['startAt'],
            ),
            gap,
            DropdownButtonFormField<int>(
              initialValue: c.durationMinutes,
              decoration: const InputDecoration(),
              items: const [
                DropdownMenuItem(value: 60, child: Text('Duration: 1 hour')),
                DropdownMenuItem(value: 120, child: Text('Duration: 2 hours')),
                DropdownMenuItem(value: 180, child: Text('Duration: 3 hours')),
                DropdownMenuItem(value: 240, child: Text('Duration: 4 hours')),
                DropdownMenuItem(value: 360, child: Text('Duration: 6 hours')),
                DropdownMenuItem(
                  value: 600,
                  child: Text('Duration: most of the day'),
                ),
              ],
              onChanged: (v) => c.update(() => c.durationMinutes = v ?? 120),
            ),
            gap,
            AppFormField(
              label: 'Venue',
              hint: 'e.g. Cafe Leopold, Colaba',
              controller: _venue,
              maxLength: 100,
              onChanged: (v) => c.venueName = v,
              validator: (_) => err['venueName'],
            ),
            gap,
            AppFormField(
              label: 'Location',
              hint: 'Choose on map',
              initialValue: c.location == null
                  ? ''
                  : 'Pinned (${c.location!.latitude.toStringAsFixed(4)}, ${c.location!.longitude.toStringAsFixed(4)})',
              readOnly: true,
              prefixIcon: Icons.place_outlined,
              onTap: () => _pickLocation(c),
              validator: (_) => err['location'],
            ),
            gap,
            AppFormField(
              label: 'Description',
              hint: 'Tell people about your plan...',
              controller: _description,
              maxLines: 4,
              maxLength: 1000,
              onChanged: (v) => c.description = v,
              validator: (_) => err['description'],
            ),
            gap,
            AppFormField(
              label: 'Max Members',
              hint: 'e.g. 10',
              controller: _maxMembers,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (v) => c.capacity = int.tryParse(v) ?? 0,
              validator: (_) => err['capacity'],
              helper: 'Including you. Between 2 and 50.',
            ),
            section('Cost'),
            AppSegmented<CostType>(
              options: const {CostType.free: 'Free', CostType.paid: 'Paid'},
              value: c.costType,
              onChanged: (v) => c.update(() => c.costType = v),
            ),
            if (c.costType == CostType.paid) ...[
              gap,
              AppFormField(
                label: 'Expected cost',
                hint: 'e.g. about ₹500 each, paid at the venue',
                controller: _costDesc,
                maxLength: 200,
                onChanged: (v) => c.costDescription = v,
                validator: (_) => err['costDescription'],
                helper:
                    'Nomad Mingle doesn\'t collect payments. Everyone pays the venue directly.',
              ),
            ],
            section('Who can join'),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('I approve each request'),
              subtitle: const Text(
                'Otherwise anyone eligible can join instantly.',
              ),
              value: c.approvalRequired,
              onChanged: (v) => c.update(() => c.approvalRequired = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Private plan'),
              subtitle: const Text('Hidden from public discovery.'),
              value: c.isPrivate,
              onChanged: (v) => c.update(() => c.isPrivate = v),
            ),
            section('Cover photo (optional)'),
            if (c.coverImageUrl != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: Image.network(
                    c.coverImageUrl!,
                    height: 140,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            SecondaryButton(
              icon: Icons.photo_outlined,
              label: c.coverImageUrl == null ? 'Add photo' : 'Change photo',
              loading: _uploading,
              onPressed: () => _pickCover(c),
            ),
            section('Good to know (optional)'),
            AppFormField(
              label: 'Safety notes',
              hint: 'Meeting point details, what to bring…',
              controller: _safety,
              maxLines: 2,
              maxLength: 500,
              onChanged: (v) => c.safetyNotes = v,
              validator: (_) => err['safetyNotes'],
            ),
            gap,
            AppFormField(
              label: 'Cancellation policy',
              controller: _cancel,
              maxLines: 2,
              maxLength: 500,
              onChanged: (v) => c.cancellationPolicy = v,
              validator: (_) => err['cancellationPolicy'],
            ),
            const SizedBox(height: 24),
            PrimaryButton(
              label: 'Create Plan',
              loading: c.submitting,
              onPressed: () => _preview(c),
            ),
          ],
        ),
      ),
    );
  }
}
