import 'package:latlong2/latlong.dart';

enum ActivityStatus { scheduled, cancelled, completed }

enum MembershipStatus { none, requested, approved, rejected, left, removed }

enum CostType { free, paid }

class Activity {
  const Activity({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.hostId,
    required this.hostDisplayName,
    required this.city,
    required this.venueName,
    required this.latitude,
    required this.longitude,
    required this.startAt,
    required this.endAt,
    required this.capacity,
    required this.participantCount,
    required this.costType,
    required this.approvalRequired,
    required this.status,
    this.hostPhotoUrl,
    this.costDescription = '',
    this.coverImageUrl,
    this.safetyNotes = '',
    this.cancellationPolicy = '',
    this.isPrivate = false,
    this.membership = MembershipStatus.none,
    this.isHost = false,
    this.distanceKm,
    this.isSummary = false,
  });

  final String id;
  final String title;
  final String description;
  final String category;
  final String hostId;
  final String hostDisplayName;
  final String? hostPhotoUrl;
  final String city;
  final String venueName;
  final double latitude;
  final double longitude;
  final DateTime startAt;
  final DateTime endAt;
  final int capacity;
  final int participantCount;
  final CostType costType;
  final String costDescription;
  final String? coverImageUrl;
  final String safetyNotes;
  final String cancellationPolicy;
  final bool approvalRequired;
  final bool isPrivate;
  final ActivityStatus status;
  final MembershipStatus membership;
  final bool isHost;
  final double? distanceKm;

  /// True for slim map-marker payloads (no host/description/capacity detail).
  final bool isSummary;

  LatLng get position => LatLng(latitude, longitude);
  int get spotsLeft => (capacity - participantCount).clamp(0, capacity);
  bool get isFull => participantCount >= capacity;
  bool get isFree => costType == CostType.free;

  Activity copyWith({
    MembershipStatus? membership,
    int? participantCount,
    double? distanceKm,
    ActivityStatus? status,
  }) => Activity(
    id: id,
    title: title,
    description: description,
    category: category,
    hostId: hostId,
    hostDisplayName: hostDisplayName,
    hostPhotoUrl: hostPhotoUrl,
    city: city,
    venueName: venueName,
    latitude: latitude,
    longitude: longitude,
    startAt: startAt,
    endAt: endAt,
    capacity: capacity,
    participantCount: participantCount ?? this.participantCount,
    costType: costType,
    costDescription: costDescription,
    coverImageUrl: coverImageUrl,
    safetyNotes: safetyNotes,
    cancellationPolicy: cancellationPolicy,
    approvalRequired: approvalRequired,
    isPrivate: isPrivate,
    status: status ?? this.status,
    membership: membership ?? this.membership,
    isHost: isHost,
    distanceKm: distanceKm ?? this.distanceKm,
    isSummary: isSummary,
  );

  factory Activity.fromJson(Map<String, dynamic> j) {
    final viewer = (j['viewer'] as Map?)?.cast<String, dynamic>();
    return Activity(
      id: j['id'] as String,
      title: j['title'] as String? ?? '',
      description: j['description'] as String? ?? '',
      category: j['category'] as String? ?? 'explore',
      hostId: j['hostId'] as String? ?? '',
      hostDisplayName: j['hostDisplayName'] as String? ?? 'Host',
      hostPhotoUrl: j['hostPhotoUrl'] as String?,
      city: j['city'] as String? ?? '',
      venueName: j['venueName'] as String? ?? '',
      latitude: (j['latitude'] as num).toDouble(),
      longitude: (j['longitude'] as num).toDouble(),
      startAt: DateTime.parse(j['startAt'] as String).toLocal(),
      endAt: DateTime.parse((j['endAt'] ?? j['startAt']) as String).toLocal(),
      // Map markers are slim: they carry `spotsLeft` instead of capacity/count.
      capacity:
          (j['capacity'] as num?)?.toInt() ??
          (j['spotsLeft'] as num?)?.toInt() ??
          0,
      participantCount: (j['participantCount'] as num?)?.toInt() ?? 0,
      isSummary: j['capacity'] == null,
      costType: j['costType'] == 'paid' ? CostType.paid : CostType.free,
      costDescription: j['costDescription'] as String? ?? '',
      coverImageUrl: j['coverImageUrl'] as String?,
      safetyNotes: j['safetyNotes'] as String? ?? '',
      cancellationPolicy: j['cancellationPolicy'] as String? ?? '',
      approvalRequired: j['approvalRequired'] as bool? ?? false,
      isPrivate: j['visibility'] == 'private',
      status: ActivityStatus.values.firstWhere(
        (s) => s.name == j['status'],
        orElse: () => ActivityStatus.scheduled,
      ),
      membership: MembershipStatus.values.firstWhere(
        (s) => s.name == viewer?['membershipStatus'],
        orElse: () => MembershipStatus.none,
      ),
      isHost: viewer?['isHost'] as bool? ?? false,
      distanceKm: (j['distanceKm'] as num?)?.toDouble(),
    );
  }
}

/// What the primary action button on an activity should show.
enum JoinUiState {
  join,
  requestToJoin,
  requested,
  joined,
  hosting,
  full,
  cancelled,
  completed,
}

JoinUiState joinUiStateFor(Activity a) {
  if (a.status == ActivityStatus.cancelled) return JoinUiState.cancelled;
  if (a.status == ActivityStatus.completed) return JoinUiState.completed;
  if (a.isHost) return JoinUiState.hosting;
  switch (a.membership) {
    case MembershipStatus.approved:
      return JoinUiState.joined;
    case MembershipStatus.requested:
      return JoinUiState.requested;
    default:
      break;
  }
  if (a.isFull) return JoinUiState.full;
  return a.approvalRequired ? JoinUiState.requestToJoin : JoinUiState.join;
}
