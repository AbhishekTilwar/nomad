import 'package:flutter_test/flutter_test.dart';
import 'package:nomad_mingle/core/services/image_upload_service.dart';

void main() {
  test('compression budgets keep stored images small', () {
    expect(
      CompressionPolicy.of(ImageKind.avatar).targetBytes,
      lessThanOrEqualTo(64 * 1024),
    );
    expect(
      CompressionPolicy.of(ImageKind.gallery).targetBytes,
      lessThanOrEqualTo(256 * 1024),
    );
    expect(
      CompressionPolicy.of(ImageKind.cover).targetBytes,
      lessThanOrEqualTo(256 * 1024),
    );
    expect(CompressionPolicy.of(ImageKind.avatar).maxEdge, 512);
    expect(CompressionPolicy.of(ImageKind.gallery).maxEdge, 1080);
  });
}
