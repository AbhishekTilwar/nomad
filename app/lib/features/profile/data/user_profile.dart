class UserProfile {
  const UserProfile({
    required this.uid,
    required this.displayName,
    required this.city,
    this.photoUrl,
    this.bio = '',
    this.interests = const [],
    this.preferredActivityTypes = const [],
    this.profileCompleted = false,
    this.accountStatus = 'active',
    this.role = 'user',
    this.countryCode,
    this.instagram,
    this.photos = const [],
  });

  final String uid;
  final String displayName;
  final String? photoUrl;
  final String bio;
  final String city;
  final List<String> interests;
  final List<String> preferredActivityTypes;
  final bool profileCompleted;
  final String accountStatus;
  final String role;
  final String? countryCode;
  final String? instagram;

  /// Extra gallery photos (max 6), shown on the public profile.
  final List<String> photos;

  bool get isStaff => role == 'admin' || role == 'moderator';

  factory UserProfile.fromJson(Map<String, dynamic> j) => UserProfile(
    uid: (j['uid'] ?? j['id']) as String,
    displayName: j['displayName'] as String? ?? '',
    photoUrl: j['photoUrl'] as String?,
    bio: j['bio'] as String? ?? '',
    city: j['city'] as String? ?? 'mumbai',
    interests: List<String>.from(j['interests'] as List? ?? const []),
    preferredActivityTypes: List<String>.from(
      j['preferredActivityTypes'] as List? ?? const [],
    ),
    profileCompleted: j['profileCompleted'] as bool? ?? false,
    accountStatus: j['accountStatus'] as String? ?? 'active',
    role: j['role'] as String? ?? 'user',
    countryCode: j['countryCode'] as String?,
    instagram: j['instagram'] as String?,
    photos: List<String>.from(j['photos'] as List? ?? const []),
  );
}

class InterestOption {
  const InterestOption(this.id, this.label);
  final String id;
  final String label;
}

/// Interests double as activity categories (ids match `AppColors.categoryColors`).
const kInterests = <InterestOption>[
  InterestOption('food', 'Food and cafes'),
  InterestOption('outings', 'Weekend outings'),
  InterestOption('travel', 'Travel'),
  InterestOption('hiking', 'Hiking and nature'),
  InterestOption('games', 'Board games'),
  InterestOption('sports', 'Sports and fitness'),
  InterestOption('photography', 'Photography'),
  InterestOption('music', 'Music and events'),
  InterestOption('movies', 'Movies'),
  InterestOption('networking', 'Networking'),
  InterestOption('art', 'Art and culture'),
  InterestOption('explore', 'Exploring new places'),
];

String interestLabel(String id) => kInterests
    .firstWhere((i) => i.id == id, orElse: () => InterestOption(id, id))
    .label;
