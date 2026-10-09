import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Profile answers collected on the sign-up screen. Never includes the
/// password or email. Applied once the account is verified.
class SignupDraft {
  const SignupDraft({
    required this.name,
    required this.dateOfBirth,
    required this.city,
    required this.interests,
  });

  final String name;
  final DateTime dateOfBirth;
  final String city;
  final List<String> interests;

  String encode() => jsonEncode({
    'name': name,
    'dob': dateOfBirth.toIso8601String(),
    'city': city,
    'interests': interests,
  });

  static SignupDraft? decode(String? raw) {
    if (raw == null) return null;
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      final dob = DateTime.tryParse(j['dob'] as String? ?? '');
      final name = j['name'] as String?;
      final city = j['city'] as String?;
      if (dob == null || name == null || city == null) return null;
      return SignupDraft(
        name: name,
        dateOfBirth: dob,
        city: city,
        interests: [for (final i in j['interests'] as List) i as String],
      );
    } catch (_) {
      return null;
    }
  }
}

class SignupDraftStore {
  const SignupDraftStore();

  static const key = 'signup_draft_v1';

  Future<SignupDraft?> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      return SignupDraft.decode(p.getString(key));
    } catch (_) {
      return null;
    }
  }

  Future<void> save(SignupDraft draft) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(key, draft.encode());
    } catch (_) {
      // Falls back to the regular onboarding steps.
    }
  }

  Future<void> clear() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.remove(key);
    } catch (_) {}
  }
}
