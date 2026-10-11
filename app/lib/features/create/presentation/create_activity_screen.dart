import 'package:flutter/cupertino.dart' show CupertinoDatePickerMode;
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
import '../../../core/utils/category_style.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/activity_card.dart';
import '../../../core/widgets/form_field.dart';
import '../../../core/widgets/app_chip.dart';
import '../../../core/widgets/picker_sheets.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/secondary_button.dart';
import '../../activities/data/activity_repository.dart';
import '../../activities/models/activity.dart';
import '../../auth/application/session_controller.dart';
import '../../profile/application/photo_gate.dart';
import '../../explore/presentation/explore_controller.dart';
import '../../profile/data/user_profile.dart';
import 'create_activity_controller.dart';

class CreateActivityScreen extends StatelessWidget {
  const CreateActivityScreen({super.key, this.editing});

  /// When set, the form edits this existing plan instead of creating one.
  final Activity? editing;

  @override
  Widget build(BuildContext context) {
    final session = context.read<SessionController>();
    return ChangeNotifierProvider(
      create: (_) => CreateActivityController(
        context.read<ActivityRepository>(),
        city: editing?.city ?? session.profile?.city ?? 'mumbai',
        editing: editing,
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
  void initState() {
    super.initState();
    final c = context.read<CreateActivityController>();
    final a = c.editing;
    if (a != null) {
      _title.text = a.title;
      _description.text = a.description;
      _venue.text = a.venueName;
      _maxMembers.text = '${a.capacity}';
      _costDesc.text = a.costDescription;
      _safety.text = a.safetyNotes;
      _cancel.text = a.cancellationPolicy;
    }
  }

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
    // Wheels move in 5-minute steps; keep every bound on that grid.
    DateTime up5(DateTime d) {
      final extra = (5 - d.minute % 5) % 5;
      return DateTime(d.year, d.month, d.day, d.hour, d.minute + extra);
    }

    final min = up5(now);
    var initial = up5(c.startAt ?? now.add(const Duration(days: 1)));
    if (initial.isBefore(min)) initial = min;
    final picked = await showDateWheelSheet(
      context,
      title: 'When does it start?',
      helper: 'Plans start at least 30 minutes from now.',
      mode: CupertinoDatePickerMode.dateAndTime,
      initial: initial,
      min: min,
      max: now.add(const Duration(days: 180)),
      minuteInterval: 5,
      confirmLabel: 'Set date and time',
      error: (d) => Validators.startTime(d),
      summary: (d) => DateFormat('EEE, d MMM · h:mm a').format(d),
    );
    if (picked != null) c.update(() => c.startAt = picked);
  }

  Future<void> _pickCategory(CreateActivityController c) async {
    final v = await showOptionSheet<String>(
      context,
      title: 'What kind of plan is it?',
      selected: c.category,
      options: [
        for (final i in kInterests)
          PickerOption(
            i.id,
            i.label,
            icon: CategoryStyle.icon(i.id),
            iconColor: CategoryStyle.color(i.id),
          ),
      ],
    );
    if (v != null) c.update(() => c.category = v);
  }

  static const _durationLabels = {
    60: '1 hour',
    120: '2 hours',
    180: '3 hours',
    240: '4 hours',
    360: '6 hours',
    600: 'Most of the day',
  };

  Future<void> _pickDuration(CreateActivityController c) async {
    final v = await showOptionSheet<int>(
      context,
      title: 'How long will it run?',
      selected: c.durationMinutes,
      options: [
        for (final e in _durationLabels.entries) PickerOption(e.key, e.value),
      ],
    );
    if (v != null) c.update(() => c.durationMinutes = v);
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
    if (c.isEditing) {
      await _saveEdit(c);
      return;
    }
    if (!await ensureProfilePhoto(
      context,
      reason: 'Add one before you host a plan.',
    )) {
      return;
    }
    if (!mounted) return;
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
      useRootNavigator: true,
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
          // Action snackbars stay forever by default; this one is just news.
          persist: false,
          duration: const Duration(seconds: 5),
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

  Future<void> _saveEdit(CreateActivityController c) async {
    final updated = await c.submit();
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    if (updated == null) {
      if (c.submitError != null) {
        messenger.showSnackBar(SnackBar(content: Text(c.submitError!)));
      }
      return;
    }
    // Refresh the map/list so the changes (and any moved pin) show up.
    context.read<ExploreController>().showPosted(updated);
    messenger.showSnackBar(const SnackBar(content: Text('Plan updated.')));
    context.pop(updated);
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
        title: Text(c.isEditing ? 'Edit Plan' : 'Create a Plan'),
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
            PickerField(
              label: 'Category',
              hint: 'Select category',
              valueText: c.category == null ? null : interestLabel(c.category!),
              errorText: err['category'],
              onTap: () => _pickCategory(c),
            ),
            gap,
            PickerField(
              label: 'Date & Time',
              hint: 'Select date & time',
              icon: Icons.calendar_today_outlined,
              valueText: c.startAt == null
                  ? null
                  : DateFormat('EEE, d MMM · h:mm a').format(c.startAt!),
              errorText: err['startAt'],
              onTap: () => _pickDateTime(c),
            ),
            gap,
            PickerField(
              label: 'Duration',
              hint: 'How long will it run?',
              valueText: _durationLabels[c.durationMinutes],
              onTap: () => _pickDuration(c),
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
                  : 'Pin dropped on the map. Tap to change.',
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
              label: 'Meeting point and notes',
              hint: 'Where exactly to meet, what to bring, anything to know…',
              controller: _safety,
              maxLines: 2,
              maxLength: 500,
              onChanged: (v) => c.safetyNotes = v,
              validator: (_) => err['safetyNotes'],
            ),
            gap,
            AppFormField(
              label: 'Cancellation policy',
              hint:
                  'e.g. Please tell the group 24 hours ahead if you can\'t come.',
              controller: _cancel,
              maxLines: 2,
              maxLength: 500,
              onChanged: (v) => c.cancellationPolicy = v,
              validator: (_) => err['cancellationPolicy'],
            ),
            const SizedBox(height: 24),
            PrimaryButton(
              label: c.isEditing ? 'Save Changes' : 'Create Plan',
              loading: c.submitting,
              onPressed: () => _preview(c),
            ),
          ],
        ),
      ),
    );
  }
}
