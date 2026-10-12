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
import '../../../core/utils/plan_emoji.dart';
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

/// Opens the "host a plan" flow as a drawer over the current screen.
Future<void> showCreatePlanSheet(BuildContext context) {
  final explore = context.read<ExploreController>();
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (sheet) {
      final h = MediaQuery.sizeOf(sheet).height;
      final keyboard = MediaQuery.viewInsetsOf(sheet).bottom;
      return Padding(
        padding: EdgeInsets.only(bottom: keyboard),
        child: ChangeNotifierProvider.value(
          value: explore,
          child: SizedBox(
            height: (h * 0.92).clamp(0, h - keyboard - 24),
            child: const CreateActivityScreen(asSheet: true),
          ),
        ),
      );
    },
  );
}

class CreateActivityScreen extends StatelessWidget {
  const CreateActivityScreen({super.key, this.editing, this.asSheet = false});

  /// When set, the form edits this existing plan instead of creating one.
  final Activity? editing;

  /// True when shown inside the drawer from [showCreatePlanSheet].
  final bool asSheet;

  @override
  Widget build(BuildContext context) {
    final session = context.read<SessionController>();
    return ChangeNotifierProvider(
      create: (_) => CreateActivityController(
        context.read<ActivityRepository>(),
        city: editing?.city ?? session.profile?.city ?? 'mumbai',
        editing: editing,
      ),
      child: _CreateView(asSheet: asSheet),
    );
  }
}

class _CreateView extends StatefulWidget {
  const _CreateView({required this.asSheet});
  final bool asSheet;

  @override
  State<_CreateView> createState() => _CreateViewState();
}

class _CreateViewState extends State<_CreateView> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _venue = TextEditingController();
  final _costDesc = TextEditingController();
  final _safety = TextEditingController();
  final _cancel = TextEditingController();
  bool _uploading = false;
  int _step = 0;
  bool _forward = true;

  List<TextEditingController> get _all => [
    _title,
    _description,
    _venue,
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
      final bad = CreateActivityController.firstStepWithError(c.errors);
      if (bad != null) {
        setState(() {
          _forward = bad > _step;
          _step = bad;
        });
      }
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
      if (widget.asSheet) Navigator.of(context).pop();
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
    _step = 0;
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

  static const _steps = <(String, String, String)>[
    ('🎯', 'What\'s the plan?', 'Pick a vibe and give it a name. A description is optional.'),
    ('🗓️', 'When & where?', 'Set the time and drop a pin so people find you.'),
    ('👥', 'Who\'s it for?', 'Group size, cost and how people get in.'),
    ('✨', 'Finishing touches', 'All optional, but a photo and a clear meeting spot help people say yes.'),
  ];

  void _next(CreateActivityController c) {
    FocusScope.of(context).unfocus();
    if (!c.validateStep(_step)) {
      HapticFeedback.lightImpact();
      return;
    }
    setState(() {
      _forward = true;
      _step++;
    });
  }

  void _back(CreateActivityController c) {
    FocusScope.of(context).unfocus();
    if (_step == 0) return;
    c.update(() => c.errors = const {});
    setState(() {
      _forward = false;
      _step--;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<CreateActivityController>();
    final t = Theme.of(context);
    final wizard = _wizard(context, c, t);
    if (widget.asSheet) {
      // Transparent so the drawer's own background shows through (no seam
      // under the drag handle).
      return Material(
        color: Colors.transparent,
        child: SafeArea(top: false, child: wizard),
      );
    }
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
      body: SafeArea(child: wizard),
    );
  }

  Widget _wizard(BuildContext context, CreateActivityController c, ThemeData t) {
    final last = _step == _steps.length - 1;
    final (emoji, title, subtitle) = _steps[_step];
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 12, 0),
          child: Row(
            children: [
              if (widget.asSheet)
                Text(
                  c.isEditing ? 'Edit plan' : 'Host a plan',
                  style: t.textTheme.titleMedium,
                )
              else
                Text(
                  'Step ${_step + 1} of ${_steps.length}',
                  style: t.textTheme.labelLarge?.copyWith(
                    color: t.colorScheme.onSurfaceVariant,
                  ),
                ),
              const Spacer(),
              if (widget.asSheet)
                IconButton(
                  tooltip: 'Close',
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
          child: Row(
            children: [
              for (var i = 0; i < _steps.length; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                Expanded(
                  child: AnimatedContainer(
                    duration: AppMotion.normal,
                    height: 5,
                    decoration: BoxDecoration(
                      color: i <= _step
                          ? t.colorScheme.primary
                          : t.colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (widget.asSheet)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Step ${_step + 1} of ${_steps.length}',
                style: t.textTheme.labelMedium?.copyWith(
                  color: t.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$emoji  $title', style: t.textTheme.headlineSmall),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: t.textTheme.bodyMedium?.copyWith(
                    color: t.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            // Fill the area and pin to the top (the default centres the step).
            layoutBuilder: (current, previous) => Stack(
              fit: StackFit.expand,
              alignment: Alignment.topCenter,
              children: [...previous, ?current],
            ),
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: SlideTransition(
                position: Tween(
                  begin: Offset(_forward ? 0.08 : -0.08, 0),
                  end: Offset.zero,
                ).animate(anim),
                child: child,
              ),
            ),
            child: KeyedSubtree(
              key: ValueKey(_step),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: _stepBody(context, c, t),
              ),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: t.colorScheme.outlineVariant)),
          ),
          child: Row(
            children: [
              if (_step > 0) ...[
                Expanded(
                  child: SecondaryButton(
                    label: 'Back',
                    onPressed: () => _back(c),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                flex: 2,
                child: PrimaryButton(
                  label: last
                      ? (c.isEditing ? 'Save changes' : 'Review & publish')
                      : 'Next',
                  loading: last && c.submitting,
                  onPressed: last ? () => _preview(c) : () => _next(c),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _stepBody(BuildContext context, CreateActivityController c, ThemeData t) {
    final err = c.errors;
    const gap = SizedBox(height: 16);
    Widget section(String s) => Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 10),
      child: Text(s, style: t.textTheme.titleMedium),
    );
    switch (_step) {
      case 0:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Vibe',
              style: t.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final i in kInterests)
                  _CategoryTile(
                    id: i.id,
                    label: CategoryStyle.shortLabels[i.id] ?? i.label,
                    selected: c.category == i.id,
                    onTap: () => c.update(() => c.category = i.id),
                  ),
              ],
            ),
            if (err['category'] != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  err['category']!,
                  style: t.textTheme.bodySmall?.copyWith(
                    color: t.colorScheme.error,
                  ),
                ),
              ),
            gap,
            AppFormField(
              label: 'Title',
              hint: 'e.g. Weekend Trek to Lonavala',
              controller: _title,
              maxLength: 80,
              onChanged: (v) => c.edit(() => c.title = v),
              errorText: err['title'],
              textInputAction: TextInputAction.next,
            ),
            gap,
            AppFormField(
              label: 'Description (optional)',
              hint: 'Tell people more about your plan...',
              controller: _description,
              maxLines: 4,
              maxLength: 1000,
              onChanged: (v) => c.edit(() => c.description = v),
              errorText: err['description'],
            ),
          ],
        );
      case 1:
        return Column(
          children: [
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
              label: 'Venue name (optional)',
              hint: 'e.g. Cafe Leopold, Colaba',
              controller: _venue,
              maxLength: 100,
              onChanged: (v) => c.edit(() => c.venueName = v),
              errorText: err['venueName'],
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
              errorText: err['location'],
            ),
          ],
        );
      case 2:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Group size',
              style: t.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton.filledTonal(
                  tooltip: 'Fewer people',
                  onPressed: c.capacity > Validators.minCapacity
                      ? () => c.update(() => c.capacity--)
                      : null,
                  icon: const Icon(Icons.remove),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text('${c.capacity}', style: t.textTheme.displaySmall),
                      Text(
                        'people, including you',
                        style: t.textTheme.bodySmall?.copyWith(
                          color: t.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: 'More people',
                  onPressed: c.capacity < Validators.maxCapacity
                      ? () => c.update(() => c.capacity++)
                      : null,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            if (err['capacity'] != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  err['capacity']!,
                  style: t.textTheme.bodySmall?.copyWith(
                    color: t.colorScheme.error,
                  ),
                ),
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
                onChanged: (v) => c.edit(() => c.costDescription = v),
                errorText: err['costDescription'],
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
          ],
        );
      default:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SummaryCard(controller: c),
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
              onChanged: (v) => c.edit(() => c.safetyNotes = v),
              errorText: err['safetyNotes'],
            ),
            gap,
            AppFormField(
              label: 'Cancellation policy',
              hint:
                  'e.g. Please tell the group 24 hours ahead if you can\'t come.',
              controller: _cancel,
              maxLines: 2,
              maxLength: 500,
              onChanged: (v) => c.edit(() => c.cancellationPolicy = v),
              errorText: err['cancellationPolicy'],
            ),
          ],
        );
    }
  }
}

/// A category as a chunky, colourful tile: emoji + label.
class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.id,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String id;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = CategoryStyle.color(id);
    // Category colours are tuned for light backgrounds; lift them on dark.
    final dark = Theme.of(context).brightness == Brightness.dark;
    final labelColor = dark ? Color.lerp(color, Colors.white, 0.5)! : color;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: AnimatedScale(
        scale: selected ? 1.04 : 1,
        duration: AppMotion.fast,
        child: Material(
          color: selected ? color : color.withValues(alpha: 0.1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: selected ? color : color.withValues(alpha: 0.35),
              width: 1.5,
            ),
          ),
          child: InkWell(
            customBorder: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 46),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      PlanEmoji.forCategory(id),
                      style: const TextStyle(fontSize: 20),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      label,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: selected ? Colors.white : labelColor,
                      ),
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

/// "Your plan so far", shown on the last step so the host can sanity-check it.
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.controller});
  final CreateActivityController controller;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final c = controller;
    final when = c.startAt == null
        ? 'Time not set'
        : DateFormat('EEE, d MMM · h:mm a').format(c.startAt!);
    final emoji = PlanEmoji.of(c.title, c.category ?? '');
    final cost = c.costType == CostType.free ? 'Free' : 'Paid';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.colorScheme.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 34)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  c.title.trim().isEmpty ? 'Untitled plan' : c.title.trim(),
                  style: t.textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  '$when\n${c.venueName.trim().isEmpty ? CreateActivityController.fallbackVenue : c.venueName.trim()}',
                  style: t.textTheme.bodyMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  'Up to ${c.capacity} people · $cost'
                  '${c.approvalRequired ? ' · Approval needed' : ''}'
                  '${c.isPrivate ? ' · Private' : ''}',
                  style: t.textTheme.bodySmall?.copyWith(
                    color: t.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
