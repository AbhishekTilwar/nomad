import 'package:flutter_test/flutter_test.dart';
import 'package:nomad_mingle/core/config/app_config.dart';

void main() {
  test('the default server address is recognised as local-only', () {
    // Tests run without --dart-define=API_BASE_URL, so this is the default.
    expect(AppConfig.apiBaseIsLocalOnly, isTrue);
  });

  test('debug and test runs are never blocked by the missing-URL guard', () {
    // Only release builds refuse to start without a real server address.
    expect(AppConfig.releaseMissingApiUrl, isFalse);
  });
}
