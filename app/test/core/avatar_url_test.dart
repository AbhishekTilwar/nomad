import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nomad_mingle/core/utils/avatar_url.dart';
import 'package:nomad_mingle/core/widgets/user_avatar.dart';
import 'package:nomad_mingle/features/profile/data/user_profile.dart';

const google = 'https://lh3.googleusercontent.com/a/ACg8ocJ-abc=s96-c';
const own = 'https://firebasestorage.googleapis.com/v0/b/x/o/me.jpg?alt=media';

void main() {
  test('Google account pictures are recognised, our uploads are not', () {
    expect(isGoogleProfilePhoto(google), isTrue);
    expect(isGoogleProfilePhoto('https://lh4.ggpht.com/x'), isTrue);
    expect(isGoogleProfilePhoto(own), isFalse);
    expect(isGoogleProfilePhoto('https://evilgoogleusercontent.com/x'), isFalse);
    expect(isGoogleProfilePhoto(null), isFalse);
    expect(ownPhotoUrl(google), isNull);
    expect(ownPhotoUrl(own), own);
    expect(ownPhotoUrls([google, own]), [own]);
  });

  test('a profile with only a Google picture counts as having no photo', () {
    final p = UserProfile.fromJson({
      'uid': 'u1',
      'displayName': 'Gita',
      'photoUrl': google,
      'photos': [google],
    });
    expect(p.photoUrl, isNull);
    expect(p.photos, isEmpty);
    final mine = UserProfile.fromJson({'uid': 'u2', 'photoUrl': own});
    expect(mine.photoUrl, own);
  });

  testWidgets('avatar shows initials, not the Google picture', (t) async {
    await t.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: UserAvatar(name: 'Gita Rao', photoUrl: google)),
      ),
    );
    expect(find.text('GR'), findsOneWidget);
  });
}
