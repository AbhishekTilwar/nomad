/// Pure validation helpers (unit-tested). Return an error string or null.
class Validators {
  const Validators._();

  static final _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');

  static String? email(String? v) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return 'Enter your email address.';
    if (!_email.hasMatch(s)) return 'That doesn\'t look like a valid email.';
    return null;
  }

  static String? password(String? v) {
    final s = v ?? '';
    if (s.isEmpty) return 'Enter a password.';
    if (s.length < 8) return 'Use at least 8 characters.';
    return null;
  }

  static String? displayName(String? v) {
    final s = v?.trim() ?? '';
    if (s.length < 2) return 'Name must be at least 2 characters.';
    if (s.length > 40) return 'Name can be at most 40 characters.';
    return null;
  }

  static String? bio(String? v) {
    if ((v?.trim().length ?? 0) > 300) {
      return 'Bio can be at most 300 characters.';
    }
    return null;
  }

  static const minAge = 18;

  /// Age in whole years on [today].
  static int ageOn(DateTime dob, DateTime today) {
    var age = today.year - dob.year;
    final hadBirthday =
        today.month > dob.month ||
        (today.month == dob.month && today.day >= dob.day);
    if (!hadBirthday) age--;
    return age;
  }

  static String? dateOfBirth(DateTime? dob, {DateTime? now}) {
    if (dob == null) return 'Select your date of birth.';
    final today = now ?? DateTime.now();
    if (dob.isAfter(today)) return 'Date of birth can\'t be in the future.';
    if (ageOn(dob, today) < minAge) {
      return 'You must be at least $minAge to use Nomad Mingle.';
    }
    return null;
  }

  // ---- Activity ----
  static String? activityTitle(String? v) {
    final s = v?.trim() ?? '';
    if (s.length < 5) return 'Give your plan a title of at least 5 characters.';
    if (s.length > 80) return 'Title can be at most 80 characters.';
    return null;
  }

  static String? activityDescription(String? v) {
    final s = v?.trim() ?? '';
    if (s.length < 20) return 'Describe the plan in at least 20 characters.';
    if (s.length > 1000) return 'Description can be at most 1000 characters.';
    return null;
  }

  static const minCapacity = 2;
  static const maxCapacity = 50;

  static String? capacity(int? v) {
    if (v == null) return 'Enter how many people can join.';
    if (v < minCapacity || v > maxCapacity) {
      return 'Capacity must be between $minCapacity and $maxCapacity.';
    }
    return null;
  }

  static String? startTime(DateTime? start, {DateTime? now}) {
    if (start == null) return 'Pick a date and time.';
    final n = now ?? DateTime.now();
    if (!start.isAfter(n.add(const Duration(minutes: 30)))) {
      return 'Start time must be at least 30 minutes from now.';
    }
    if (start.isAfter(n.add(const Duration(days: 180)))) {
      return 'Plans can be created up to 6 months ahead.';
    }
    return null;
  }

  // ---- Chat ----
  static const maxMessageLength = 500;

  static String? message(String? v) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return 'Write a message first.';
    if (s.length > maxMessageLength) {
      return 'Messages can be at most $maxMessageLength characters.';
    }
    return null;
  }
}
