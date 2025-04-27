import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logging/logging.dart';
import '../services/language_service.dart';
import '../widgets/translated_text.dart';

class LanguageSettingsScreen extends StatefulWidget {
  const LanguageSettingsScreen({Key? key}) : super(key: key);

  @override
  State<LanguageSettingsScreen> createState() => _LanguageSettingsScreenState();
}

class _LanguageSettingsScreenState extends State<LanguageSettingsScreen> {
  final _logger = Logger('LanguageSettingsScreen');
  String _selectedLanguage = 'en'; // Default to English
  String _selectedUrduFont = 'NotoNastaliqUrdu'; // Default Urdu font

  final List<Map<String, dynamic>> _languages = [
    {'code': 'en', 'name': 'English', 'localName': 'English', 'flag': '🇬🇧'},
    {
      'code': 'hi',
      'name': 'हिंदी (Hindi)',
      'localName': 'हिंदी',
      'flag': '🇮🇳'
    },
    {'code': 'ur', 'name': 'اردو (Urdu)', 'localName': 'اردو', 'flag': '🇵🇰'},
    {
      'code': 'bn',
      'name': 'বাংলা (Bengali)',
      'localName': 'বাংলা',
      'flag': '🇧🇩'
    },
  ];

  final List<Map<String, dynamic>> _urduFonts = [
    {
      'name': 'System Default',
      'family': '', // Empty string for system default
      'preview': 'اردو فونٹ',
    },
    {
      'name': 'Noto Nastaliq Urdu',
      'family': 'NotoNastaliqUrdu',
      'preview': 'اردو فونٹ',
    },
    {
      'name': 'Jameel Noori Nastaleeq',
      'family': 'JameelNooriNastaleeqKasheeda',
      'preview': 'اردو فونٹ',
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadSelectedLanguage();
    _loadSelectedUrduFont();
  }

  Future<void> _loadSelectedLanguage() async {
    try {
      final currentLanguage = LanguageService.instance.currentLanguage;
      _logger.info('Current language loaded: $currentLanguage');

      setState(() {
        _selectedLanguage = currentLanguage;
      });
    } catch (e, stackTrace) {
      _logger.severe('Error loading selected language', e, stackTrace);
      setState(() {
        _selectedLanguage = 'en';
      });
    }
  }

  Future<void> _loadSelectedUrduFont() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedFont = prefs.getString('urdu_font');
      setState(() {
        _selectedUrduFont = savedFont ?? 'NotoNastaliqUrdu';
      });
    } catch (e) {
      _logger.severe('Error loading selected Urdu font', e);
    }
  }

  Future<void> _setLanguage(String languageCode) async {
    _logger.info('Attempting to set language to: $languageCode');
    if (_selectedLanguage == languageCode) {
      _logger.info('Language already set to $languageCode, ignoring');
      return;
    }

    try {
      if (languageCode == 'ur') {
        // Show font selection dialog for Urdu
        final selectedFont = await showDialog<String>(
          context: context,
          builder: (context) => AlertDialog(
            title: const TranslatedText('select_urdu_font'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: _urduFonts.map((font) {
                  return RadioListTile<String>(
                    title: Text(font['name'] as String),
                    subtitle: Text(
                      font['preview'] as String,
                      style: TextStyle(
                        fontFamily: font['family'] as String?,
                        fontSize: 20,
                        height: 1.5,
                      ),
                    ),
                    value: font['family'] as String,
                    groupValue: _selectedUrduFont,
                    onChanged: (value) {
                      Navigator.pop(context, value);
                    },
                  );
                }).toList(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const TranslatedText('cancel'),
              ),
            ],
          ),
        );

        if (selectedFont == null) return;

        // Save selected font
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('urdu_font', selectedFont);
        setState(() {
          _selectedUrduFont = selectedFont;
        });
      }

      final success = await LanguageService.instance.setLanguage(languageCode);

      if (success) {
        _logger.info('Language successfully changed to: $languageCode');
        setState(() {
          _selectedLanguage = languageCode;
        });

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: TranslatedText('language_changed'),
            duration: Duration(seconds: 2),
          ),
        );

        // Instead of resetting the app, just pop back to previous screen
        if (mounted) {
          Navigator.pop(context);
        }
      } else {
        _logger.warning('Failed to change language to: $languageCode');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: TranslatedText('language_change_failed'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e, stackTrace) {
      _logger.severe('Error setting language', e, stackTrace);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const TranslatedText('language_settings'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info card
            Card(
              elevation: 2,
              margin: const EdgeInsets.only(bottom: 20),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue[700]),
                        const SizedBox(width: 8),
                        Text(
                          'language_information'.tr,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[700],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const TranslatedText(
                      'language_info_description',
                      style: TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),

            const TranslatedText(
              'select_language',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),

            // Language list
            Expanded(
              child: ListView.builder(
                itemCount: _languages.length,
                itemBuilder: (context, index) {
                  final language = _languages[index];
                  final isSelected = language['code'] == _selectedLanguage;

                  return Card(
                    elevation: isSelected ? 3 : 1,
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    color: isSelected ? Colors.blue.withOpacity(0.1) : null,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: isSelected ? Colors.blue : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: InkWell(
                      onTap: () => _setLanguage(language['code'] as String),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            // Flag emoji
                            Text(
                              language['flag'] as String? ?? '',
                              style: const TextStyle(fontSize: 30),
                            ),
                            const SizedBox(width: 16),
                            // Language details
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    language['name'] as String? ?? '',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    language['localName'] as String? ?? '',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Selection indicator
                            if (isSelected)
                              const Icon(Icons.check_circle, color: Colors.blue)
                            else
                              const Icon(Icons.circle_outlined,
                                  color: Colors.grey),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            // Footer
            const SizedBox(height: 16),
            Center(
              child: Text(
                'Additional languages will be added in future updates',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
