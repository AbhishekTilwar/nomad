import '../../../core/api/api_client.dart';
import '../../../core/utils/app_exception.dart';
import 'user_profile.dart';

abstract class ProfileRepository {
  /// Returns null when the user has no profile yet (needs onboarding).
  Future<UserProfile?> fetchMe();

  Future<UserProfile> createProfile({
    required String displayName,
    required DateTime dateOfBirth,
    required String city,
    required String bio,
    required List<String> interests,
    required List<String> preferredActivityTypes,
    String? photoUrl,
  });

  Future<UserProfile> updateProfile({
    String? displayName,
    String? bio,
    String? city,
    List<String>? interests,
    List<String>? preferredActivityTypes,
    String? photoUrl,
    bool removePhoto = false,
  });

  Future<void> deleteAccountData();
}

class ApiProfileRepository implements ProfileRepository {
  ApiProfileRepository(this._api);
  final ApiClient _api;

  static String _dob(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Future<UserProfile?> fetchMe() async {
    try {
      final res = await _api.get('/users/me');
      return UserProfile.fromJson(res.asMap);
    } on AppException catch (e) {
      if (e.code == 'not_found' || e.code == '404') return null;
      rethrow;
    }
  }

  @override
  Future<UserProfile> createProfile({
    required String displayName,
    required DateTime dateOfBirth,
    required String city,
    required String bio,
    required List<String> interests,
    required List<String> preferredActivityTypes,
    String? photoUrl,
  }) async {
    final res = await _api.put(
      '/users/me',
      body: {
        'displayName': displayName.trim(),
        'dateOfBirth': _dob(dateOfBirth),
        'city': city,
        'bio': bio.trim(),
        'interests': interests,
        'preferredActivityTypes': preferredActivityTypes,
        'photoUrl': ?photoUrl,
      },
    );
    return UserProfile.fromJson(res.asMap);
  }

  @override
  Future<UserProfile> updateProfile({
    String? displayName,
    String? bio,
    String? city,
    List<String>? interests,
    List<String>? preferredActivityTypes,
    String? photoUrl,
    bool removePhoto = false,
  }) async {
    final res = await _api.patch(
      '/users/me',
      body: {
        if (displayName != null) 'displayName': displayName.trim(),
        if (bio != null) 'bio': bio.trim(),
        'city': ?city,
        'interests': ?interests,
        'preferredActivityTypes': ?preferredActivityTypes,
        // null clears the photo on the server; absent leaves it unchanged.
        if (removePhoto) 'photoUrl': null else 'photoUrl': ?photoUrl,
      },
    );
    return UserProfile.fromJson(res.asMap);
  }

  @override
  Future<void> deleteAccountData() async {
    await _api.delete('/users/me');
  }
}
