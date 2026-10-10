import 'dart:ui';

import 'package:google_mlkit_language_id/google_mlkit_language_id.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';

class TranslationResult {
  const TranslationResult(this.text, {this.sourceLanguage});
  final String text;

  /// BCP-47 code detected for the source text, when known.
  final String? sourceLanguage;
}

/// Translates user-written text into the device language. Implemented with
/// on-device ML Kit (no text leaves the phone; models download once on demand).
abstract class TranslationService {
  /// Throws [TranslationException] when the language can't be detected or
  /// the model can't be downloaded.
  Future<TranslationResult> translate(String text, {String? targetLanguage});
}

class TranslationException implements Exception {
  const TranslationException(this.message);
  final String message;
  @override
  String toString() => message;
}

class MlKitTranslationService implements TranslationService {
  @override
  Future<TranslationResult> translate(
    String text, {
    String? targetLanguage,
  }) async {
    final target = TranslateLanguage.values.firstWhere(
      (l) =>
          l.bcpCode ==
          (targetLanguage ?? PlatformDispatcher.instance.locale.languageCode),
      orElse: () => TranslateLanguage.english,
    );
    final identifier = LanguageIdentifier(confidenceThreshold: 0.4);
    final translator = OnDeviceTranslatorModelManager();
    try {
      final code = await identifier.identifyLanguage(text);
      if (code == 'und') {
        throw const TranslationException(
          'Couldn\'t tell what language this is.',
        );
      }
      final source = TranslateLanguage.values.where((l) => l.bcpCode == code);
      if (source.isEmpty) {
        throw const TranslationException('That language isn\'t supported yet.');
      }
      if (source.first == target) {
        return TranslationResult(text, sourceLanguage: code);
      }
      for (final l in [source.first, target]) {
        if (!await translator.isModelDownloaded(l.bcpCode)) {
          await translator.downloadModel(l.bcpCode);
        }
      }
      final t = OnDeviceTranslator(
        sourceLanguage: source.first,
        targetLanguage: target,
      );
      try {
        return TranslationResult(
          await t.translateText(text),
          sourceLanguage: code,
        );
      } finally {
        await t.close();
      }
    } on TranslationException {
      rethrow;
    } catch (_) {
      throw const TranslationException(
        'Translation needs an internet connection the first time.',
      );
    } finally {
      await identifier.close();
    }
  }
}
