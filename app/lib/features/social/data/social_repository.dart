import '../../../core/api/api_client.dart';

enum Friendship { none, friends, requestSent, requestReceived }

Friendship friendshipFromString(String? s) => switch (s) {
  'friends' => Friendship.friends,
  'request_sent' => Friendship.requestSent,
  'request_received' => Friendship.requestReceived,
  _ => Friendship.none,
};

/// A nearby member who opted in to being discoverable. Distance is rounded
/// by the server and the coordinates themselves are never sent.
class Traveler {
  const Traveler({
    required this.uid,
    required this.displayName,
    this.photoUrl,
    this.countryCode,
    this.city = '',
    this.distanceKm,
  });
  final String uid;
  final String displayName;
  final String? photoUrl;
  final String? countryCode;
  final String city;
  final double? distanceKm;

  factory Traveler.fromJson(Map<String, dynamic> j) => Traveler(
    uid: (j['uid'] ?? j['id']) as String,
    displayName: j['displayName'] as String? ?? 'Member',
    photoUrl: j['photoUrl'] as String?,
    countryCode: j['countryCode'] as String?,
    city: j['city'] as String? ?? '',
    distanceKm: (j['distanceKm'] as num?)?.toDouble(),
  );
}

abstract class SocialRepository {
  Future<Friendship> sendFriendRequest(String uid);
  Future<void> acceptFriendRequest(String uid);

  /// Cancels a pending request, declines an incoming one, or unfriends.
  Future<void> removeFriend(String uid);

  Future<List<Traveler>> travelers({
    required double lat,
    required double lng,
    double radiusKm = 50,
  });

  /// Opt in/out of appearing in "travelers in area". Only ~1 km-rounded
  /// coordinates are stored, and only while [discoverable] is true.
  Future<void> setLocation({
    required double lat,
    required double lng,
    required bool discoverable,
  });
}

class ApiSocialRepository implements SocialRepository {
  ApiSocialRepository(this._api);
  final ApiClient _api;

  @override
  Future<Friendship> sendFriendRequest(String uid) async {
    final res = await _api.post('/users/$uid/friend-request');
    return friendshipFromString(res.asMap['friendship'] as String?) ==
            Friendship.friends
        ? Friendship.friends
        : Friendship.requestSent;
  }

  @override
  Future<void> acceptFriendRequest(String uid) async {
    await _api.post('/users/$uid/friend-request/accept');
  }

  @override
  Future<void> removeFriend(String uid) async {
    await _api.delete('/users/$uid/friend');
  }

  @override
  Future<List<Traveler>> travelers({
    required double lat,
    required double lng,
    double radiusKm = 50,
  }) async => (await _api.get(
    '/users/travelers',
    query: {'lat': lat, 'lng': lng, 'radiusKm': radiusKm, 'limit': 50},
  )).asList.map(Traveler.fromJson).toList();

  @override
  Future<void> setLocation({
    required double lat,
    required double lng,
    required bool discoverable,
  }) async {
    await _api.put(
      '/users/me/location',
      body: {'lat': lat, 'lng': lng, 'discoverable': discoverable},
    );
  }
}
