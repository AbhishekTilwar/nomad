import '../../../core/api/api_client.dart';
import '../models/activity.dart';

class ActivityPage {
  const ActivityPage(this.items, this.nextCursor);
  final List<Activity> items;
  final String? nextCursor;
}

class ActivityQuery {
  const ActivityQuery({
    this.city,
    this.category,
    this.keyword,
    this.freeOnly = false,
    this.from,
    this.to,
    this.minSpots,
    this.lat,
    this.lng,
    this.radiusKm,
    this.sort = 'date',
    this.cursor,
    this.limit = 20,
  });

  final String? city;
  final String? category;
  final String? keyword;
  final bool freeOnly;
  final DateTime? from;
  final DateTime? to;
  final int? minSpots;
  final double? lat;
  final double? lng;
  final double? radiusKm;
  final String sort;
  final String? cursor;
  final int limit;

  Map<String, dynamic> toQuery() => {
    'city': city,
    'category': category,
    'q': keyword,
    if (freeOnly) 'free': 'true',
    'from': from?.toUtc().toIso8601String(),
    'to': to?.toUtc().toIso8601String(),
    'minSpots': minSpots,
    'lat': lat,
    'lng': lng,
    'radiusKm': radiusKm,
    'sort': sort,
    'cursor': cursor,
    'limit': limit,
  };
}

/// Query seam: the map UI only depends on this interface, so the geohash
/// implementation (server-side) can be swapped for a dedicated geo service.
abstract class ActivityRepository {
  Future<ActivityPage> list(ActivityQuery query);
  Future<List<Activity>> forMap({
    required double lat,
    required double lng,
    required double radiusKm,
    String? category,
  });
  Future<Activity> get(String id);
  Future<Activity> create(ActivityDraft draft);

  /// Returns the resulting membership status (`approved` or `requested`).
  Future<MembershipStatus> join(String id);
  Future<void> leave(String id);
  Future<void> cancel(String id);
  Future<List<ActivityMember>> members(String id);
  Future<void> approve(String id, String uid);
  Future<void> reject(String id, String uid);
  Future<void> remove(String id, String uid);
}

class ActivityMember {
  const ActivityMember({
    required this.userId,
    required this.displayName,
    required this.status,
    required this.role,
    this.photoUrl,
  });
  final String userId;
  final String displayName;
  final String? photoUrl;
  final MembershipStatus status;
  final String role;

  factory ActivityMember.fromJson(Map<String, dynamic> j) => ActivityMember(
    userId: (j['userId'] ?? j['id']) as String,
    displayName: j['displayName'] as String? ?? 'Member',
    photoUrl: j['photoUrl'] as String?,
    role: j['role'] as String? ?? 'participant',
    status: MembershipStatus.values.firstWhere(
      (s) => s.name == j['status'],
      orElse: () => MembershipStatus.none,
    ),
  );
}

/// Everything needed to publish an activity. Timestamps are sent as UTC ISO strings.
class ActivityDraft {
  const ActivityDraft({
    required this.title,
    required this.description,
    required this.category,
    required this.city,
    required this.venueName,
    required this.latitude,
    required this.longitude,
    required this.startAt,
    required this.endAt,
    required this.capacity,
    required this.costType,
    required this.approvalRequired,
    this.costDescription = '',
    this.isPrivate = false,
    this.safetyNotes = '',
    this.cancellationPolicy = '',
    this.coverImageUrl,
  });

  final String title;
  final String description;
  final String category;
  final String city;
  final String venueName;
  final double latitude;
  final double longitude;
  final DateTime startAt;
  final DateTime endAt;
  final int capacity;
  final CostType costType;
  final String costDescription;
  final bool approvalRequired;
  final bool isPrivate;
  final String safetyNotes;
  final String cancellationPolicy;
  final String? coverImageUrl;

  Map<String, dynamic> toJson() => {
    'title': title.trim(),
    'description': description.trim(),
    'category': category,
    'city': city,
    'venueName': venueName.trim(),
    'latitude': latitude,
    'longitude': longitude,
    'startAt': startAt.toUtc().toIso8601String(),
    'endAt': endAt.toUtc().toIso8601String(),
    'capacity': capacity,
    'costType': costType.name,
    'costDescription': costDescription.trim(),
    'approvalRequired': approvalRequired,
    'visibility': isPrivate ? 'private' : 'public',
    'safetyNotes': safetyNotes.trim(),
    'cancellationPolicy': cancellationPolicy.trim(),
    'coverImageUrl': ?coverImageUrl,
  };
}

class ApiActivityRepository implements ActivityRepository {
  ApiActivityRepository(this._api);
  final ApiClient _api;

  @override
  Future<ActivityPage> list(ActivityQuery q) async {
    final res = await _api.get('/activities', query: q.toQuery());
    return ActivityPage(
      res.asList.map(Activity.fromJson).toList(),
      res.nextCursor,
    );
  }

  @override
  Future<List<Activity>> forMap({
    required double lat,
    required double lng,
    required double radiusKm,
    String? category,
  }) async {
    final res = await _api.get(
      '/activities/map',
      query: {
        'lat': lat,
        'lng': lng,
        'radiusKm': radiusKm,
        'category': category,
        'limit': 100,
      },
    );
    return res.asList.map(Activity.fromJson).toList();
  }

  @override
  Future<Activity> get(String id) async =>
      Activity.fromJson((await _api.get('/activities/$id')).asMap);

  @override
  Future<Activity> create(ActivityDraft draft) async => Activity.fromJson(
    (await _api.post('/activities', body: draft.toJson())).asMap,
  );

  @override
  Future<MembershipStatus> join(String id) async {
    final res = await _api.post('/activities/$id/join');
    return res.asMap['status'] == 'requested'
        ? MembershipStatus.requested
        : MembershipStatus.approved;
  }

  @override
  Future<void> leave(String id) async {
    await _api.post('/activities/$id/leave');
  }

  @override
  Future<void> cancel(String id) async {
    await _api.post('/activities/$id/cancel');
  }

  @override
  Future<List<ActivityMember>> members(String id) async => (await _api.get(
    '/activities/$id/members',
  )).asList.map(ActivityMember.fromJson).toList();

  @override
  Future<void> approve(String id, String uid) async {
    await _api.post('/activities/$id/approve/$uid');
  }

  @override
  Future<void> reject(String id, String uid) async {
    await _api.post('/activities/$id/reject/$uid');
  }

  @override
  Future<void> remove(String id, String uid) async {
    await _api.post('/activities/$id/remove/$uid');
  }
}
