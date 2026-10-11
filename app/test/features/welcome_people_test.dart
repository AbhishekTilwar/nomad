import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nomad_mingle/features/auth/presentation/welcome_people.dart';

/// 1x1 PNG.
final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

class _Bundle extends CachingAssetBundle {
  _Bundle(this.files);
  final Map<String, Uint8List> files;

  @override
  Future<ByteData> load(String key) async {
    final f = files[key];
    if (f == null) throw FlutterError('missing $key');
    return ByteData.sublistView(f);
  }
}

void main() {
  test(
    'no photos provided: empty list, no error (illustrated fallback)',
    () async {
      expect(await WelcomePeople.load(bundle: _Bundle({})), isEmpty);
    },
  );

  test(
    'provided photos are loaded; missing and broken ones are skipped',
    () async {
      final photos = await WelcomePeople.load(
        bundle: _Bundle({
          WelcomePeople.assetNames[0]: _png,
          WelcomePeople.assetNames[2]: Uint8List.fromList([
            1,
            2,
            3,
          ]), // not an image
          WelcomePeople.assetNames[3]: _png,
        }),
      );
      expect(photos, hasLength(2));
    },
  );
}
