import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/language_service.dart';
import '../widgets/translated_text.dart';

class SettingsScreen extends StatefulWidget {
  final Function(double)? updateNavBarOpacity;

  const SettingsScreen({super.key, this.updateNavBarOpacity});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Settings state variables
  String _selectedTheme = 'System';
  String _selectedFontSize = 'Medium';
  String _selectedAccentColor = 'Teal';
  String _selectedLanguage = 'English';
  double _navBarOpacity = 1.0; // Start with full opacity
  final ScrollController _scrollController = ScrollController();
  final double _cornerRadius = 10.0;
  String? _mosqueCode;

  // Language options that match the language translations available in the app
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

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadMosqueCode();
    _scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    const double fadeStart = 20.0;
    const double fadeEnd = 120.0;

    double newOpacity = 1.0; // Start with full opacity

    if (_scrollController.offset <= fadeStart) {
      newOpacity = 1.0; // Fully opaque at the top
    } else if (_scrollController.offset < fadeEnd) {
      // Calculate opacity from 1.0 to 0.0 as user scrolls
      newOpacity = 1.0 -
          ((_scrollController.offset - fadeStart) / (fadeEnd - fadeStart));
    } else {
      newOpacity = 0.0; // Fully transparent after scrolling past fadeEnd
    }

    setState(() {
      _navBarOpacity = newOpacity;
    });

    if (widget.updateNavBarOpacity != null) {
      widget.updateNavBarOpacity!(newOpacity);
    }
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentLanguage = LanguageService.instance.currentLanguage;
      setState(() {
        _selectedTheme = prefs.getString('theme_mode') ?? 'System';
        _selectedFontSize = prefs.getString('font_size') ?? 'Medium';
        _selectedAccentColor = prefs.getString('accent_color') ?? 'Teal';
        _selectedLanguage = _getLanguageDisplay(currentLanguage);
      });
    } catch (e) {
      // Handle error
    }
  }

  String _getLanguageDisplay(String code) {
    for (var language in _languages) {
      if (language['code'] == code) {
        return language['localName'];
      }
    }
    return 'English';
  }

  String _getLanguageCode(String display) {
    for (var language in _languages) {
      if (language['localName'] == display) {
        return language['code'];
      }
    }
    return 'en';
  }

  Future<void> _setLanguage(String display) async {
    final languageCode = _getLanguageCode(display);
    final success = await LanguageService.instance.setLanguage(languageCode);
    if (success) {
      setState(() => _selectedLanguage = display);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: TranslatedText('language_changed'),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _saveSettings(String key, dynamic value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (value is String) {
        await prefs.setString(key, value);
      } else if (value is bool) {
        await prefs.setBool(key, value);
      }
    } catch (e) {
      // Handle error
    }
  }

  Future<void> _loadMosqueCode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final code = prefs.getString('mosque_code');
      setState(() {
        _mosqueCode = code;
      });
    } catch (e) {
      // Handle error
    }
  }

  // Get the current language code
  String get _currentLanguageCode => LanguageService.instance.currentLanguage;

  // Translate with fallback for settings-specific terms
  String _translateWithFallback(String key) {
    // Always try the language service first
    String translation = LanguageService.instance.translate(key);

    // If the translation returns the key itself (no translation found), use our fallbacks
    if (translation == key) {
      // Fallback translations for settings screen items
      final fallbackTranslations = {
        'ur': {
          'font_size': 'فونٹ سائز',
          'accent_color': 'ایکسینٹ کلر',
          'version': 'ورژن',
          'developed_by': 'ڈویلپر',
          'secure_code': 'سیکیور کوڈ',
          'code_copied': 'سیکیور کوڈ کلپ بورڈ پر کاپی ہو گیا',
          'change_language': 'زبان تبدیل کریں',
        },
        'hi': {
          'font_size': 'फॉन्ट साइज़',
          'accent_color': 'एक्सेंट कलर',
          'version': 'वर्शन',
          'developed_by': 'डेवलपर',
          'secure_code': 'सुरक्षित कोड',
          'code_copied': 'सुरक्षित कोड क्लिपबोर्ड पर कॉपी किया गया',
          'change_language': 'भाषा बदलें',
        },
        'bn': {
          'font_size': 'ফন্ট সাইজ',
          'accent_color': 'অ্যাকসেন্ট কালার',
          'version': 'ভার্সন',
          'developed_by': 'ডেভেলপার',
          'secure_code': 'সিকিউর কোড',
          'code_copied': 'সিকিউর কোড ক্লিপবোর্ডে কপি করা হয়েছে',
          'change_language': 'ভাষা পরিবর্তন করুন',
        },
      };

      // Get translation from fallbacks if available
      final langFallbacks = fallbackTranslations[_currentLanguageCode];
      if (langFallbacks != null && langFallbacks.containsKey(key)) {
        return langFallbacks[key]!;
      }
    }

    return translation;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Get the height of the status bar for proper spacing
    final statusBarHeight = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      extendBodyBehindAppBar: true,
      // Add an AppBar here to ensure we have our own app bar when displayed in HomeScreen
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(statusBarHeight + 50),
        child: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              color: Colors.white.withOpacity(0.7),
              padding: EdgeInsets.only(
                top: statusBarHeight,
                left: 20,
                right: 20,
              ),
              height: statusBarHeight + 50,
              child: const Row(
                children: [
                  Expanded(
                    child: Center(
                      child: TranslatedText(
                        'settings',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            controller: _scrollController,
            padding: EdgeInsets.only(
              top: statusBarHeight + 50,
              left: 16.0,
              right: 16.0,
              bottom: 120.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildSection(
                  'appearance_settings'.tr,
                  [
                    _buildDropdownSetting(
                      'theme_settings'.tr,
                      Icons.palette,
                      _selectedTheme,
                      ['System', 'Light', 'Dark'],
                      (value) {
                        setState(() => _selectedTheme = value);
                        _saveSettings('theme_mode', value);
                      },
                    ),
                    _buildDropdownSetting(
                      _translateWithFallback('font_size'),
                      Icons.text_fields,
                      _selectedFontSize,
                      ['Small', 'Medium', 'Large'],
                      (value) {
                        setState(() => _selectedFontSize = value);
                        _saveSettings('font_size', value);
                      },
                    ),
                    _buildDropdownSetting(
                      _translateWithFallback('accent_color'),
                      Icons.color_lens,
                      _selectedAccentColor,
                      ['Teal', 'Blue', 'Purple', 'Green'],
                      (value) {
                        setState(() => _selectedAccentColor = value);
                        _saveSettings('accent_color', value);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildSection(
                  'language_settings'.tr,
                  [
                    _buildLanguageSelector(),
                  ],
                ),
                const SizedBox(height: 16),
                _buildSection(
                  'about_app'.tr,
                  [
                    _buildInfoItem(
                      _translateWithFallback('version'),
                      Icons.info,
                      '1.0.0',
                    ),
                    _buildInfoItem(
                      _translateWithFallback('developed_by'),
                      Icons.people,
                      'Ajaj',
                    ),
                  ],
                ),
                if (_mosqueCode != null) ...[
                  const SizedBox(height: 16),
                  _buildSection(
                    'share'.tr,
                    [
                      _buildShareItem(
                        _translateWithFallback('secure_code'),
                        Icons.share,
                        _mosqueCode!,
                        onCopy: () async {
                          await Clipboard.setData(
                              ClipboardData(text: _mosqueCode!));
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content:
                                  Text(_translateWithFallback('code_copied')),
                              backgroundColor: Colors.green,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                _buildSection(
                  'support_development'.tr,
                  [
                    _buildSupportItem(
                      'buy_me_coffee'.tr,
                      Icons.coffee,
                      'support_development'.tr,
                      onTap: () {
                        _showDonationPopup(context);
                      },
                    ),
                    _buildSupportItem(
                      'contact_developer'.tr,
                      Icons.support_agent,
                      'get_technical_help'.tr,
                      onTap: () {
                        _showDeveloperContact(context);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(179),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: Colors.white.withAlpha(128),
                    width: 1,
                  ),
                ),
                child: Column(
                  children: children,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.teal.withAlpha(51),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.language,
              color: Colors.teal,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              _translateWithFallback('change_language'),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Container(
            width: 130,
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(20),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedLanguage,
                icon: const Icon(Icons.arrow_drop_down, color: Colors.teal),
                elevation: 16,
                style: const TextStyle(color: Colors.black87),
                isExpanded: true,
                alignment: Alignment.center,
                underline: Container(height: 0),
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    _setLanguage(newValue);
                  }
                },
                items: _languages.map<DropdownMenuItem<String>>(
                    (Map<String, dynamic> language) {
                  return DropdownMenuItem<String>(
                    value: language['localName'],
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(language['flag'] as String),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            language['localName'],
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownSetting(
    String title,
    IconData icon,
    String currentValue,
    List<String> options,
    Function(String) onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.teal.withAlpha(51),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: Colors.teal,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Container(
            width: 130,
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(20),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: currentValue,
                icon: const Icon(Icons.arrow_drop_down, color: Colors.teal),
                elevation: 16,
                style: const TextStyle(color: Colors.black87),
                isExpanded: true,
                alignment: Alignment.center,
                underline: Container(height: 0),
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    onChanged(newValue);
                  }
                },
                items: options.map<DropdownMenuItem<String>>((String value) {
                  // Find the corresponding language item to get the flag
                  final langItem = _languages.firstWhere(
                    (lang) => lang['localName'] == value,
                    orElse: () => {'flag': '🌐'},
                  );

                  return DropdownMenuItem<String>(
                    value: value,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(langItem['flag'] as String),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            value,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String title, IconData icon, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.teal.withAlpha(51),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: Colors.teal,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShareItem(
    String title,
    IconData icon,
    String value, {
    required VoidCallback onCopy,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.teal.withAlpha(51),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: Colors.teal,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy, color: Colors.teal),
            onPressed: onCopy,
            tooltip: 'Copy to clipboard',
          ),
        ],
      ),
    );
  }

  Widget _buildSupportItem(
    String title,
    IconData icon,
    String subtitle, {
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.teal.withAlpha(51),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: Colors.teal,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  void _showDonationPopup(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.coffee, color: Colors.brown),
            SizedBox(width: 8),
            TranslatedText('buy_me_coffee'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const TranslatedText(
              'premium_description',
              style: TextStyle(fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Image.asset(
                    'assets/images/upi_qr.png',
                    height: 200,
                    width: 200,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () async {
                      final upiUrl = Uri.parse(
                          'upi://pay?pa=7079553517@ybl&pn=Ajaj%20Abbas%20Ali&am=&cu=INR&tn=Support%20App%20Development');
                      try {
                        if (await canLaunchUrl(upiUrl)) {
                          await launchUrl(upiUrl,
                              mode: LaunchMode.externalApplication);
                        } else {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                  'No UPI app found. Please install Google Pay, PhonePe, or Paytm.'),
                              backgroundColor: Colors.red,
                              duration: Duration(seconds: 3),
                            ),
                          );
                        }
                      } catch (e) {
                        if (!mounted) return;
                        final scaffoldMessenger = ScaffoldMessenger.of(context);
                        scaffoldMessenger.showSnackBar(
                          SnackBar(
                            content: const Text(
                                'Failed to open UPI app. Please try again.'),
                            backgroundColor: Colors.red,
                            duration: const Duration(seconds: 3),
                            action: SnackBarAction(
                              label: 'Copy UPI ID',
                              onPressed: () {
                                Clipboard.setData(const ClipboardData(
                                    text: '7079553517@ybl'));
                                scaffoldMessenger.showSnackBar(
                                  const SnackBar(
                                    content: Text('UPI ID copied to clipboard'),
                                    backgroundColor: Colors.green,
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              },
                            ),
                          ),
                        );
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 8, horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue[200]!),
                      ),
                      child: const SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.payment, color: Colors.blue),
                            SizedBox(width: 8),
                            Text(
                              'UPI ID: 7079553517@ybl',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Colors.blue,
                              ),
                            ),
                            SizedBox(width: 8),
                            Icon(Icons.open_in_new,
                                size: 16, color: Colors.blue),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Click to pay directly',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const TranslatedText('close'),
          ),
        ],
      ),
    );
  }

  void _showDeveloperContact(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.support_agent, color: Colors.blue),
            SizedBox(width: 8),
            TranslatedText('contact_developer'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildContactItem(Icons.person, 'Name', 'Ajaj Abbas Ali'),
            const SizedBox(height: 12),
            _buildContactItem(Icons.phone, 'Mobile', '+91 7079553517'),
            const SizedBox(height: 12),
            _buildContactItem(Icons.email, 'Email', 'ajaj42699@gmail.com'),
            const SizedBox(height: 12),
            _buildContactItem(Icons.link, 'Instagram', 'ajaj_x_ajaj'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const TranslatedText('close'),
          ),
        ],
      ),
    );
  }

  Widget _buildContactItem(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
