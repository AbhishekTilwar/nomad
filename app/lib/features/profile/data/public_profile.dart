import '../../../core/api/api_client.dart';
import '../../social/data/social_repository.dart';

/// What any signed-in member may see about another member (`GET /users/:uid`).
/// Date of birth and exact location are never part of this.
class PublicProfile {
  const PublicProfile({
    required this.uid,
    required this.displayName,
    required this.city,
    this.photoUrl,
    this.bio = '',
    this.interests = const [],
    this.ageRange,
    this.emailVerified = false,
    this.hosted = 0,
    this.attended = 0,
    this.countryCode,
    this.instagram,
    this.friendship = Friendship.none,
    this.photos = const [],
  });

  final String uid;
  final String displayName;
  final String? photoUrl;
  final String bio;
  final String city;
  final List<String> interests;
  final String? ageRange;
  final bool emailVerified;
  final int hosted;
  final int attended;
  final String? countryCode;
  final String? instagram;
  final Friendship friendship;
  final List<String> photos;

  factory PublicProfile.fromJson(String uid, Map<String, dynamic> j) {
    final stats = (j['stats'] as Map?)?.cast<String, dynamic>() ?? const {};
    return PublicProfile(
      uid: uid,
      displayName: j['displayName'] as String? ?? 'Member',
      photoUrl: j['photoUrl'] as String?,
      bio: j['bio'] as String? ?? '',
      city: j['city'] as String? ?? '',
      interests: List<String>.from(j['interests'] as List? ?? const []),
      ageRange: j['ageRange'] as String?,
      emailVerified: j['emailVerified'] as bool? ?? false,
      hosted: (stats['hosted'] as num?)?.toInt() ?? 0,
      attended: (stats['attended'] as num?)?.toInt() ?? 0,
      countryCode: j['countryCode'] as String?,
      instagram: j['instagram'] as String?,
      friendship: friendshipFromString(j['friendship'] as String?),
      photos: List<String>.from(j['photos'] as List? ?? const []),
    );
  }
}

abstract class PublicProfileRepository {
  Future<PublicProfile> fetch(String uid);
}

class ApiPublicProfileRepository implements PublicProfileRepository {
  ApiPublicProfileRepository(this._api);
  final ApiClient _api;

  @override
  Future<PublicProfile> fetch(String uid) async =>
      PublicProfile.fromJson(uid, (await _api.get('/users/$uid')).asMap);
}
