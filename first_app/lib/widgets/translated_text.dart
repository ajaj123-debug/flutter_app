import 'package:flutter/material.dart';
import '../services/language_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A widget that automatically translates text based on the current app language
class TranslatedText extends StatelessWidget {
  /// The key for translation
  final String translationKey;

  /// Text style
  final TextStyle? style;

  /// Text alignment
  final TextAlign? textAlign;

  /// Maximum number of lines
  final int? maxLines;

  /// Overflow behavior
  final TextOverflow? overflow;

  const TranslatedText(
    this.translationKey, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _getFontFamily(),
      builder: (context, snapshot) {
        final currentLanguage = LanguageService.instance.currentLanguage;
        final baseStyle = style ?? const TextStyle();

        // Apply Urdu font if language is Urdu and font is loaded
        final textStyle = currentLanguage == 'ur' && snapshot.hasData
            ? baseStyle.copyWith(
                fontFamily: snapshot.data,
                height: 1.5, // Add some line height for better readability
              )
            : baseStyle;

        return Text(
          LanguageService.instance.translate(translationKey),
          style: textStyle,
          textAlign: textAlign,
          maxLines: maxLines,
          overflow: overflow,
        );
      },
    );
  }

  Future<String> _getFontFamily() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedFont = prefs.getString('urdu_font');
      return savedFont ?? 'NotoNastaliqUrdu';
    } catch (e) {
      return 'NotoNastaliqUrdu'; // Fallback to default font
    }
  }
}

/// Extension for easy translation of strings
extension TranslationExtension on String {
  String get tr => LanguageService.instance.translate(this);
}
