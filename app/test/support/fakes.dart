import 'dart:async';

import 'package:nomad_mingle/features/activities/data/activity_repository.dart';
import 'package:nomad_mingle/features/activities/models/activity.dart';
import 'package:nomad_mingle/features/auth/data/auth_repository.dart';
import 'package:nomad_mingle/features/profile/data/profile_repository.dart';
import 'package:nomad_mingle/features/profile/data/user_profile.dart';

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository([AuthUser? initial]) : _user = initial {
    // Mirrors Firebase: current state is emitted on subscription.
  }

  final _listeners = <StreamController<AuthUser?>>[];
  AuthUser? _user;
  AuthFailure? failNext;
  int signInCalls = 0;

  @override
  Stream<AuthUser?> authStateChanges() {
    late final StreamController<AuthUser?> c;
    c = StreamController<AuthUser?>(
      onListen: () {
        _listeners.add(c);
        c.add(_user); // Firebase emits the current state on subscribe.
      },
      onCancel: () => _listeners.remove(c),
    );
    return c.stream;
  }

  void emit(AuthUser? u) {
    _user = u;
    for (final l in List.of(_listeners)) {
      l.add(u);
    }
  }

  @override
  AuthUser? get currentUser => _user;

  void _maybeFail() {
    final f = failNext;
    if (f != null) {
      failNext = null;
      throw f;
    }
  }

  @override
  Future<void> signInWithEmail(String email, String password) async {
    signInCalls++;
    _maybeFail();
    emit(
      AuthUser(
        uid: 'u1',
        email: email,
        emailVerified: true,
        usesPassword: true,
      ),
    );
  }

  @override
  Future<void> registerWithEmail(String email, String password) async {
    _maybeFail();
    emit(
      AuthUser(
        uid: 'u1',
        email: email,
        emailVerified: false,
        usesPassword: true,
      ),
    );
  }

  @override
  Future<void> signInWithGoogle() async {
    _maybeFail();
    emit(
      const AuthUser(
        uid: 'g1',
        email: 'g@x.com',
        emailVerified: true,
        displayName: 'Gita',
      ),
    );
  }

  bool verified = false;

  @override
  Future<AuthUser?> reload() async {
    if (verified && _user != null) {
      _user = AuthUser(
        uid: _user!.uid,
        email: _user!.email,
        emailVerified: true,
        usesPassword: true,
      );
    }
    return _user;
  }

  @override
  Future<void> sendPasswordReset(String email) async => _maybeFail();
  @override
  Future<void> sendEmailVerification() async {}
  @override
  Future<String?> idToken({bool forceRefresh = false}) async => 'token';
  @override
  Future<void> signOut() async => emit(null);
  @override
  Future<void> deleteAccount({String? password}) async => emit(null);
}

class FakeProfileRepository implements ProfileRepository {
  FakeProfileRepository({this.profile});
  UserProfile? profile;
  Object? fetchError;
  DateTime? lastDob;

  @override
  Future<UserProfile?> fetchMe() async {
    if (fetchError != null) throw fetchError!;
    return profile;
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
    lastDob = dateOfBirth;
    return profile = UserProfile(
      uid: 'u1',
      displayName: displayName,
      photoUrl: photoUrl,
      city: city,
      bio: bio,
      interests: interests,
      profileCompleted: true,
    );
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
    String? countryCode,
    String? instagram,
    List<String>? photos,
  }) async {
    lastPhotoUrl = photoUrl;
    lastRemovePhoto = removePhoto;
    return profile = UserProfile(
      uid: profile!.uid,
      displayName: displayName ?? profile!.displayName,
      photoUrl: removePhoto ? null : (photoUrl ?? profile!.photoUrl),
      city: city ?? profile!.city,
      bio: bio ?? profile!.bio,
      interests: interests ?? profile!.interests,
      countryCode: countryCode ?? profile!.countryCode,
      instagram: instagram ?? profile!.instagram,
      photos: photos ?? profile!.photos,
      profileCompleted: true,
    );
  }

  String? lastPhotoUrl;
  bool lastRemovePhoto = false;

  @override
  Future<void> deleteAccountData() async {}
}

class FakeActivityRepository implements ActivityRepository {
  FakeActivityRepository([this.activities = const []]);
  List<Activity> activities;
  Object? error;

  @override
  Future<ActivityPage> list(ActivityQuery query) async =>
      ActivityPage(activities, null);

  @override
  Future<List<Activity>> forMap({
    required double lat,
    required double lng,
    required double radiusKm,
    String? category,
  }) async {
    if (error != null) throw error!;
    return activities;
  }

  @override
  Future<Activity> get(String id) async {
    if (error != null) throw error!;
    return activities.firstWhere((a) => a.id == id);
  }

  ActivityDraft? created;
  int createCalls = 0;
  final joined = <String>[];
  final left = <String>[];
  final cancelled = <String>[];
  final decisions = <String>[];
  List<ActivityMember> memberList = const [];

  @override
  Future<Activity> create(ActivityDraft d) async {
    createCalls++;
    if (error != null) throw error!;
    created = d;
    return sampleActivity(
      id: 'new',
      title: d.title,
      capacity: d.capacity,
      participants: 1,
    );
  }

  String? updatedId;
  ActivityDraft? updatedDraft;

  @override
  Future<Activity> update(String id, ActivityDraft d) async {
    if (error != null) throw error!;
    updatedId = id;
    updatedDraft = d;
    return sampleActivity(id: id, title: d.title, capacity: d.capacity);
  }

  @override
  Future<MembershipStatus> join(String id) async {
    if (error != null) throw error!;
    joined.add(id);
    final a = activities.firstWhere((a) => a.id == id);
    return a.approvalRequired
        ? MembershipStatus.requested
        : MembershipStatus.approved;
  }

  @override
  Future<void> leave(String id) async => left.add(id);
  @override
  Future<void> cancel(String id) async => cancelled.add(id);
  @override
  Future<List<ActivityMember>> members(String id) async => memberList;
  @override
  Future<void> approve(String id, String uid) async =>
      decisions.add('approve:$uid');
  @override
  Future<void> reject(String id, String uid) async =>
      decisions.add('reject:$uid');
  @override
  Future<void> remove(String id, String uid) async =>
      decisions.add('remove:$uid');
}

Activity sampleActivity({
  String id = 'a1',
  String title = 'Sunday brunch at Kala Ghoda',
  int capacity = 6,
  int participants = 2,
  bool approvalRequired = false,
  ActivityStatus status = ActivityStatus.scheduled,
  MembershipStatus membership = MembershipStatus.none,
  bool isHost = false,
  CostType cost = CostType.free,
}) => Activity(
  id: id,
  title: title,
  description: 'Casual brunch, all welcome to join the table.',
  category: 'food',
  hostId: 'h1',
  hostDisplayName: 'Riya Shah',
  city: 'mumbai',
  venueName: 'Kala Ghoda Cafe',
  latitude: 18.93,
  longitude: 72.83,
  startAt: DateTime.now().add(const Duration(days: 2)),
  endAt: DateTime.now().add(const Duration(days: 2, hours: 2)),
  capacity: capacity,
  participantCount: participants,
  costType: cost,
  approvalRequired: approvalRequired,
  status: status,
  membership: membership,
  isHost: isHost,
);
