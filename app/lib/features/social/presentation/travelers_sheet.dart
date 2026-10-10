import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/location_service.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/app_exception.dart';
import '../../../core/utils/countries.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/user_avatar.dart';
import '../data/social_repository.dart';

const _kDiscoverableKey = 'discoverable_v1';

/// "Travelers in area": members near you who opted in. Only roughly rounded
/// positions are stored server-side, and only while you are discoverable.
class TravelersSheet extends StatefulWidget {
  const TravelersSheet({super.key});

  static Future<void> show(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) =>
        const FractionallySizedBox(heightFactor: 0.8, child: TravelersSheet()),
  );

  @override
  State<TravelersSheet> createState() => _TravelersSheetState();
}

class _TravelersSheetState extends State<TravelersSheet> {
  List<Traveler>? _items;
  String? _error;
  bool _loading = true;
  bool _discoverable = false;
  double? _lat;
  double? _lng;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _discoverable = prefs.getBool(_kDiscoverableKey) ?? false;
    await _load();
  }

  Future<void> _load() async {
    final location = context.read<LocationService>();
    final social = context.read<SocialRepository>();
    setState(() {
      _loading = true;
      _error = null;
    });
    final r = await location.current();
    if (!mounted) return;
    final p = r.position;
    if (p == null) {
      setState(() {
        _loading = false;
        _error = locationMessage(r.outcome);
      });
      return;
    }
    _lat = p.latitude;
    _lng = p.longitude;
    try {
      if (_discoverable) {
        await social.setLocation(
          lat: p.latitude,
          lng: p.longitude,
          discoverable: true,
        );
      }
      final list = await social.travelers(lat: p.latitude, lng: p.longitude);
      if (mounted) setState(() => _items = list);
    } on AppException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _toggle(bool on) async {
    final social = context.read<SocialRepository>();
    final messenger = ScaffoldMessenger.of(context);
    final lat = _lat, lng = _lng;
    if (lat == null || lng == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Turn on location to be discoverable.')),
      );
      return;
    }
    setState(() => _discoverable = on);
    try {
      await social.setLocation(lat: lat, lng: lng, discoverable: on);
      (await SharedPreferences.getInstance()).setBool(_kDiscoverableKey, on);
    } on AppException catch (e) {
      if (mounted) setState(() => _discoverable = !on);
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final items = _items;
    Widget body;
    if (_loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_error != null) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: _load, child: const Text('Try again')),
            ],
          ),
        ),
      );
    } else if (items == null || items.isEmpty) {
      body = const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No travelers nearby yet. Turn on "Show me here" so others can find you too.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    } else {
      body = ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (_, i) {
          final tr = items[i];
          final flag = flagEmoji(tr.countryCode);
          return Material(
            color: t.colorScheme.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            elevation: 1,
            shadowColor: Colors.black26,
            child: ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              leading: Stack(
                clipBehavior: Clip.none,
                children: [
                  UserAvatar(
                    name: tr.displayName,
                    photoUrl: tr.photoUrl,
                    size: 48,
                  ),
                  if (flag != null)
                    Positioned(
                      right: -6,
                      bottom: -4,
                      child: Text(flag, style: const TextStyle(fontSize: 18)),
                    ),
                ],
              ),
              title: Text(
                tr.displayName,
                style: t.textTheme.titleMedium?.copyWith(fontSize: 15),
              ),
              subtitle: Text(
                [
                  if (countryName(tr.countryCode).isNotEmpty)
                    countryName(tr.countryCode),
                  if (tr.distanceKm != null) Formatters.distance(tr.distanceKm),
                ].join(' · '),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).pop();
                context.push(
                  '/user/${tr.uid}',
                  extra: {'name': tr.displayName, 'photoUrl': tr.photoUrl},
                );
              },
            ),
          );
        },
      );
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  items == null
                      ? 'Travelers in area'
                      : '${items.length} travelers in area',
                  style: t.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Close',
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
        SwitchListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20),
          title: const Text('Show me here'),
          subtitle: const Text(
            'Others nearby can see your name, photo and rough distance. Turn off any time.',
          ),
          value: _discoverable,
          onChanged: _toggle,
        ),
        const Divider(height: 1),
        Expanded(child: body),
      ],
    );
  }
}
