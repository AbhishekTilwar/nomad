import 'package:flutter_test/flutter_test.dart';
import 'package:nomad_mingle/core/utils/validators.dart';

void main() {
  group('email/password', () {
    test('email', () {
      expect(Validators.email(''), isNotNull);
      expect(Validators.email('nope'), isNotNull);
      expect(Validators.email(' a@b.co '), isNull);
    });
    test('password needs 8 chars', () {
      expect(Validators.password('short'), isNotNull);
      expect(Validators.password('longenough'), isNull);
    });
  });

  group('date of birth / age eligibility', () {
    final now = DateTime(2026, 10, 10);
    test('rejects missing and future dates', () {
      expect(Validators.dateOfBirth(null, now: now), isNotNull);
      expect(Validators.dateOfBirth(DateTime(2027), now: now), isNotNull);
    });
    test('17 years 364 days is rejected, exactly 18 is accepted', () {
      expect(
        Validators.dateOfBirth(DateTime(2008, 10, 11), now: now),
        isNotNull,
      );
      expect(Validators.dateOfBirth(DateTime(2008, 10, 10), now: now), isNull);
    });
    test('ageOn handles birthday not yet reached', () {
      expect(Validators.ageOn(DateTime(2000, 12, 1), now), 25);
      expect(Validators.ageOn(DateTime(2000, 10, 10), now), 26);
    });
  });

  group('profile', () {
    test('display name bounds', () {
      expect(Validators.displayName('A'), isNotNull);
      expect(Validators.displayName('Ab'), isNull);
      expect(Validators.displayName('x' * 41), isNotNull);
    });
    test('bio max 300', () {
      expect(Validators.bio('x' * 301), isNotNull);
      expect(Validators.bio('x' * 300), isNull);
    });
  });

  group('activity creation', () {
    final now = DateTime(2026, 10, 10, 12);
    test('title and description', () {
      expect(Validators.activityTitle('Hey'), isNotNull);
      expect(Validators.activityTitle('Sunday brunch'), isNull);
      expect(Validators.activityDescription('too short'), isNotNull);
      expect(Validators.activityDescription('x' * 30), isNull);
    });
    test('capacity bounds 2..50', () {
      expect(Validators.capacity(null), isNotNull);
      expect(Validators.capacity(1), isNotNull);
      expect(Validators.capacity(51), isNotNull);
      expect(Validators.capacity(2), isNull);
      expect(Validators.capacity(50), isNull);
    });
    test('start time must be in the future window', () {
      expect(Validators.startTime(null, now: now), isNotNull);
      expect(
        Validators.startTime(now.subtract(const Duration(hours: 1)), now: now),
        isNotNull,
      );
      expect(
        Validators.startTime(now.add(const Duration(minutes: 10)), now: now),
        isNotNull,
      );
      expect(
        Validators.startTime(now.add(const Duration(days: 2)), now: now),
        isNull,
      );
      expect(
        Validators.startTime(now.add(const Duration(days: 400)), now: now),
        isNotNull,
      );
    });
  });

  group('message length', () {
    test('empty and whitespace rejected', () {
      expect(Validators.message(''), isNotNull);
      expect(Validators.message('   '), isNotNull);
    });
    test('500 ok, 501 rejected', () {
      expect(Validators.message('a' * 500), isNull);
      expect(Validators.message('a' * 501), isNotNull);
    });
  });
}
