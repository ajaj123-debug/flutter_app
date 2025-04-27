import 'package:shared_preferences/shared_preferences.dart';
import 'package:logging/logging.dart';
import 'dart:async';

class LanguageService {
  static final LanguageService _instance = LanguageService._internal();
  static LanguageService get instance => _instance;

  // Logger for debugging
  final _logger = Logger('LanguageService');

  // Stream controller for language changes
  final StreamController<String> _languageChangeController =
      StreamController<String>.broadcast();
  Stream<String> get onLanguageChanged => _languageChangeController.stream;

  LanguageService._internal() {
    _logger.info('LanguageService initialized');
  }

  String _currentLanguage = 'en'; // Default language is English

  // Initialize the language service
  Future<void> initialize() async {
    _logger.info('Initializing language service...');
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedLanguage = prefs.getString('language_code');

      if (savedLanguage != null) {
        _currentLanguage = savedLanguage;
        _logger.info('Loaded language from preferences: $_currentLanguage');
      } else {
        _logger
            .info('No saved language found, using default: $_currentLanguage');
      }

      // Log available translations
      _logger.info('Available languages: ${_translations.keys.join(', ')}');
      _logger.info('Sample translations for current language:');
      final sampleKeys = ['dashboard', 'settings', 'total_income'];
      for (final key in sampleKeys) {
        _logger.info('  "$key" -> "${translate(key)}"');
      }
    } catch (e, stackTrace) {
      _logger.severe('Error initializing language service', e, stackTrace);
      // Fall back to default language
      _currentLanguage = 'en';
    }
  }

  // Get current language code
  String get currentLanguage => _currentLanguage;

  // Translate a given string based on the current language
  String translate(String key) {
    // If translation doesn't exist, return the original string
    final translated = _translations[_currentLanguage]?[key] ??
        _translations['en']?[key] ??
        key;

    // Removing fine level logging for translation attempts
    // These were causing too many log messages in the console

    return translated;
  }

  // Shorthand method for translation
  String t(String key) => translate(key);

  // Set language and log the change
  Future<bool> setLanguage(String languageCode) async {
    if (!_translations.containsKey(languageCode)) {
      _logger.warning('Attempted to set unsupported language: $languageCode');
      return false;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('language_code', languageCode);

      // Only notify if language actually changed
      final oldLanguage = _currentLanguage;
      _currentLanguage = languageCode;
      _logger.info('Language changed to: $languageCode');

      // Log some sample translations in the new language
      _logger.info('Sample translations for new language:');
      final sampleKeys = ['dashboard', 'settings', 'total_income'];
      for (final key in sampleKeys) {
        _logger.info('  "$key" -> "${translate(key)}"');
      }

      // Notify listeners of language change
      if (oldLanguage != languageCode) {
        _logger.info(
            'Notifying listeners of language change from $oldLanguage to $languageCode');
        _languageChangeController.add(languageCode);
      }

      return true;
    } catch (e, stackTrace) {
      _logger.severe('Error setting language', e, stackTrace);
      return false;
    }
  }

  // Dispose resources
  void dispose() {
    _languageChangeController.close();
  }

  // Map of translations for all supported languages
  static final Map<String, Map<String, String>> _translations = {
    'en': {
      // Dashboard and main screens
      'dashboard': 'Dashboard',
      'accounts': 'Accounts',
      'summary': 'Summary',
      'reports': 'Reports',
      'settings': 'Settings',

      // Navigation items
      'manage_accounts': 'Manage Accounts',
      'manage_payers': 'Manage Payers',
      'manage_expense_categories': 'Manage Expense Categories',
      'admin_panel': 'Admin Panel',
      'go_premium': 'Go Premium',

      // Settings screen
      'appearance_settings': 'Appearance Settings',
      'language_settings': 'Language Settings',
      'report_settings': 'Report Settings',
      'theme_settings': 'Theme Settings',
      'data_recovery': 'Data Recovery',
      'contact_developer': 'Contact Developer',
      'buy_me_coffee': 'Buy Me a Coffee',
      'about_app': 'About the App',

      // Actions & buttons
      'add': 'Add',
      'edit': 'Edit',
      'delete': 'Delete',
      'save': 'Save',
      'cancel': 'Cancel',
      'confirm': 'Confirm',
      'close': 'Close',
      'view_pdf': 'View PDF',
      'save_pdf': 'Save PDF',
      'view_reports_analysis': 'Reports Analysis',
      'share_report': 'Share Report',

      // Summary screen
      'total_income': 'Total Income',
      'total_deductions': 'Expenses',
      'total_savings': 'Total Savings',
      'this_month': 'This Month',
      'last_month': 'Last Month',
      'total_balance': 'Total Balance',
      'recent_transactions': 'Recent Transactions',
      'recent_deductions': 'Recent Deductions',
      'unknown_payer': 'Unknown Payer',

      // Transaction related
      'income': 'Income',
      'expense': 'Expense',
      'deduction': 'Deduction',
      'transaction': 'Transaction',
      'payer': 'Payer',
      'category': 'Category',
      'amount': 'Amount',
      'date': 'Date',
      'description': 'Description',

      // Reports
      'report_information': 'Report Information',
      'select_month': 'Select Month',
      'pending_payments': 'Pending Payments',
      'report_information_description':
          'Reports can be viewed directly or saved to your device\'s download folder. You can access saved reports through your file explorer.',

      // UI elements
      'customize_app_look': 'Customize app look and feel',
      'change_language': 'Change app language',
      'configure_report': 'Configure report title and format',
      'switch_theme': 'Switch between light and dark mode',
      'backup_restore': 'Backup or restore data',
      'get_technical_help': 'Get help with technical issues',
      'support_development': 'Support the development of this app',
      'learn_more': 'Learn more about Mosque Ease',
      'unlock_premium': 'Unlock exclusive features and remove ads',

      // New keys
      'quick_access': 'Quick Access',
      'data': 'Data',
      'cloud_database': 'Cloud Database',
      'sync_data': 'Sync Data',
      'language_information': 'Language Information',
      'select_language': 'Select Language',
      'items_count': '{count} items',
      'payers_list': 'Payers List',
      'categories_list': 'Categories List',
      'no_payers_yet': 'No payers yet',
      'no_categories_yet': 'No categories yet',
      'add_payer_to_get_started': 'Add a new payer to get started',
      'add_category_to_get_started': 'Add a new category to get started',
      'enter_payer_name': 'Enter Payer Name',
      'enter_category_name': 'Enter Category Name',
      'please_enter_payer_name': 'Please enter a payer name',
      'please_enter_category_name': 'Please enter a category name',
      'add_payer': 'ADD PAYER',
      'add_category': 'ADD CATEGORY',
      'payer_added_successfully': 'Payer added Successfully',
      'category_added_successfully': 'Category added Successfully',
      'payer_deleted_successfully': 'Payer deleted Successfully',
      'category_deleted_successfully': 'Category deleted Successfully',
      'error_unique_payer_name': 'Error: Payer name must be unique',
      'error_unique_category_name': 'Error: Category name must be unique',
      'error_deleting_payer': 'Error deleting payer',
      'error_deleting_category': 'Error deleting category',
      'confirm_delete_payer': 'Are you sure you want to delete "{name}"?',
      'confirm_delete_category': 'Are you sure you want to delete "{name}"?',

      // Manager screen
      'add_income': 'Add Income',
      'add_deduction': 'Add Deduction',
      'select_payer': 'Select Payer',
      'select_category': 'Select Category',
      'enter_amount': 'Enter Amount',
      'enter_deduction_amount': 'Enter Deduction Amount',
      'selected_date': 'Selected Date',
      'add_amount': 'ADD AMOUNT',
      'deduct_amount': 'DEDUCT AMOUNT',
      'please_select_payer': 'Please select a payer',
      'please_select_category': 'Please select a category',
      'please_enter_amount': 'Please enter an amount',
      'please_enter_valid_number': 'Please enter a valid number',

      // Role-based access translations
      'manager_role': 'Manager',
      'viewer_role': 'Viewer',
      'access_denied': 'Access Denied',
      'manager_only': 'This feature is only available to managers',
      'insufficient_permissions':
          'You do not have permission to perform this action',

      // Language settings
      'language_changed': 'Language changed successfully',
      'language_change_failed': 'Failed to change language. Please try again.',
      'language_info_description':
          'This setting changes the app interface language. Numbers, dates, and currency symbols will remain unchanged for accuracy.',
      'select_urdu_font': 'Select Urdu Font',

      // Reports screen additional translations
      'currency_label': 'Currency: {symbol}',
      'transactions_copied': 'Transactions copied to clipboard!',
      'monthly_report_title': '{month} {year} Report 📊',
      'income_section': 'Income 📥',
      'expense_section': 'Expenses 🛒',
      'summary_section': 'Summary',
      'income_emoji': 'Income💰',
      'expense_emoji': 'Expenses💸',
      'savings_emoji': 'Savings 💵',
      'pending_payment_request':
          '*Please request the following people to send their payment for {month} as soon as possible:*',
      'share_report': 'Share Report',
      'select_what_to_share': 'Select what you want to share',
      'full_report': 'Full Report',
      'full_report_description': 'Includes all transactions and summary',
      'non_payers_list': 'Non-payers List',
      'non_payers_description': 'List of members who haven\'t paid yet',
      'cancel': 'Cancel',
      'share': 'Share',

      // Premium upgrade dialog
      'premium_title': 'Premium Upgrade',
      'premium_description': 'Enhance Your Mosque Management',
      'premium_feature_charts': 'Advanced charts & visualization',
      'premium_feature_reports': 'Beautiful designed reports',
      'premium_feature_backup': 'Priority cloud backup',
      'premium_feature_adfree': 'Ad-free experience',
      'maybe_later': 'Maybe Later',
      'upgrade_now': 'Upgrade Now',

      // Add missing settings translations
      'font_size': 'Font Size',
      'accent_color': 'Accent Color',
      'version': 'Version',
      'developed_by': 'Developed by',
      'secure_code': 'Secure Code',
      'code_copied': 'Secure code copied to clipboard',
      'offline_backup': 'Offline Backup',
      'create_offline_backup': 'Create offline backup of your data',
    },
    'hi': {
      // Dashboard and main screens
      'dashboard': 'डैशबोर्ड',
      'accounts': 'हिसाब',
      'summary': 'खुलासा',
      'reports': 'रिपोर्ट',
      'settings': 'सेटिंग्स',

      // Navigation items
      'manage_accounts': 'हिसाब का इंतजाम करें',
      'manage_payers': 'देने वालों का इंतजाम करें',
      'manage_expense_categories': 'खर्च की किस्मों का इंतजाम करें',
      'admin_panel': 'एडमिन पैनल',
      'go_premium': 'प्रीमियम बनें',

      // Settings screen
      'appearance_settings': 'नजर की सेटिंग्स',
      'language_settings': 'जुबान की सेटिंग्स',
      'report_settings': 'रिपोर्ट की सेटिंग्स',
      'theme_settings': 'थीम की सेटिंग्स',
      'data_recovery': 'डेटा की बहाली',
      'contact_developer': 'डेवलपर से राब्ता करें',
      'buy_me_coffee': 'मुझे कॉफी पिलाएं',
      'about_app': 'ऐप के बारे में',

      // Actions & buttons
      'add': 'शामिल करें',
      'edit': 'तरमीम करें',
      'delete': 'हटाएं',
      'save': 'महफूज करें',
      'cancel': 'रद्द करें',
      'confirm': 'तसदीक करें',
      'close': 'बंद करें',
      'view_pdf': 'पीडीएफ देखें',
      'save_pdf': 'पीडीएफ महफूज करें',
      'view_reports_analysis': 'रिपोर्ट का तज्जिया देखें',
      'share_report': 'रिपोर्ट शेयर करें',

      // Summary screen
      'total_income': 'कुल आमदनी',
      'total_deductions': 'कुल खर्च',
      'total_savings': 'कुल बचत',
      'this_month': 'इस महीने',
      'last_month': 'पिछले महीने',
      'total_balance': 'कुल बाकी',
      'recent_transactions': 'हाल के लेन-देन',
      'recent_deductions': 'हाल के खर्च',
      'unknown_payer': 'नामालूम देने वाला',

      // Transaction related
      'income': 'आमदनी',
      'expense': 'खर्च',
      'deduction': 'कटौती',
      'transaction': 'लेन-देन',
      'payer': 'देने वाला',
      'category': 'किस्म',
      'amount': 'रकम',
      'date': 'तारीख',
      'description': 'तफसील',

      // Reports
      'report_information': 'रिपोर्ट की मालूमात',
      'select_month': 'महीना चुनें',
      'pending_payments': 'बाकी पैसे',
      'report_information_description':
          'रिपोर्ट को सीधे देखा जा सकता है या आपके डिवाइस के डाउनलोड फोल्डर में महफूज किया जा सकता है। आप फाइल एक्सप्लोरर के जरिए महफूज की गई रिपोर्ट तक पहुंच सकते हैं।',

      // UI elements
      'customize_app_look': 'ऐप की नजर को अपनी मर्जी के मुताबिक बनाएं',
      'change_language': 'ऐप की जुबान बदलें',
      'configure_report': 'रिपोर्ट शीर्षक और फॉर्मेट तरतीब दें',
      'switch_theme': 'लाइट और डार्क मोड के दरमियान बदलें',
      'backup_restore': 'डेटा का बैकअप या बहाली करें',
      'get_technical_help': 'तकनीकी मदद हासिल करें',
      'support_development': 'इस ऐप की तरक्की की हिमायत करें',
      'learn_more': 'मस्जिद ईज़ के बारे में और जानें',
      'unlock_premium': 'खास सुविधाओं को अनलॉक करें और इश्तिहार हटाएं',

      // New keys
      'quick_access': 'जल्दी पहुंच',
      'data': 'डेटा',
      'cloud_database': 'क्लाउड डेटाबेस',
      'sync_data': 'डेटा सिंक करें',
      'language_information': 'जुबान की मालूमात',
      'select_language': 'जुबान चुनें',
      'items_count': '{count} आइटम',
      'payers_list': 'देने वालों की सूची',
      'categories_list': 'श्रेणियों की सूची',
      'no_payers_yet': 'अभी तक कोई देने वाला नहीं',
      'no_categories_yet': 'अभी तक कोई श्रेणी नहीं',
      'add_payer_to_get_started': 'शुरू करने के लिए एक नया देने वाला जोड़ें',
      'add_category_to_get_started': 'शुरू करने के लिए एक नई श्रेणी जोड़ें',
      'enter_payer_name': 'देने वाले का नाम दर्ज करें',
      'enter_category_name': 'श्रेणी का नाम दर्ज करें',
      'please_enter_payer_name': 'कृपया देने वाले का नाम दर्ज करें',
      'please_enter_category_name': 'कृपया श्रेणी का नाम दर्ज करें',
      'add_payer': 'देने वाला जोड़ें',
      'add_category': 'श्रेणी जोड़ें',
      'payer_added_successfully': 'देने वाला सफलतापूर्वक जोड़ा गया',
      'category_added_successfully': 'श्रेणी सफलतापूर्वक जोड़ी गई',
      'payer_deleted_successfully': 'देने वाला सफलतापूर्वक हटा दिया गया',
      'category_deleted_successfully': 'श्रेणी सफलतापूर्वक हटा दी गई',
      'error_unique_payer_name': 'त्रुटि: देने वाले का नाम अद्वितीय होना चाहिए',
      'error_unique_category_name': 'त्रुटि: श्रेणी का नाम अद्वितीय होना चाहिए',
      'error_deleting_payer': 'देने वाले को हटाने में त्रुटि',
      'error_deleting_category': 'श्रेणी को हटाने में त्रुटि',
      'confirm_delete_payer': 'क्या आप वाकई "{name}" को हटाना चाहते हैं?',
      'confirm_delete_category': 'क्या आप वाकई "{name}" को हटाना चाहते हैं?',

      // Manager screen
      'add_income': 'आमदनी शामिल करें',
      'add_deduction': 'खर्च शामिल करें',
      'select_payer': 'देने वाला चुनें',
      'select_category': 'किस्म चुनें',
      'enter_amount': 'रकम दर्ज करें',
      'enter_deduction_amount': 'खर्च की रकम दर्ज करें',
      'selected_date': 'चुनी हुई तारीख',
      'add_amount': 'रकम शामिल करें',
      'deduct_amount': 'रकम काटें',
      'please_select_payer': 'कृपया एक देने वाला चुनें',
      'please_select_category': 'कृपया एक किस्म चुनें',
      'please_enter_amount': 'कृपया एक रकम दर्ज करें',
      'please_enter_valid_number': 'कृपया एक दुरुस्त नंबर दर्ज करें',

      // Role-based access translations
      'manager_role': 'मैनेजर',
      'viewer_role': 'देखने वाला',
      'access_denied': 'पहुंच मना की गई',
      'manager_only': 'यह सुविधा सिर्फ मैनेजरों के लिए मौजूद है',
      'insufficient_permissions': 'आपके पास यह काम करने की इजाजत नहीं है',

      // Language settings
      'language_changed': 'जुबान कामयाबी से बदल दी गई',
      'language_change_failed':
          'जुबान बदलने में नाकाम। कृपया दोबारा कोशिश करें।',
      'language_info_description':
          'यह सेटिंग ऐप इंटरफेस की जुबान बदलती है। दुरुस्ती के लिए नंबर, तारीख और करेंसी के निशान बदलेंगे नहीं।',
      'select_urdu_font': 'उर्दू फॉन्ट चुनें',

      // Reports screen additional translations
      'currency_label': 'करेंसी: {symbol}',
      'transactions_copied': 'लेन-देन क्लिपबोर्ड पर कॉपी हो गए!',
      'monthly_report_title': '{month} {year} हिसाब 📊',
      'income_section': 'आमदनी 📥',
      'expense_section': 'खर्च 🛒',
      'summary_section': 'खुलासा',
      'income_emoji': 'आमदनी💰',
      'expense_emoji': 'खर्च💸',
      'savings_emoji': 'बचत 💵',
      'pending_payment_request':
          '*इन हजरत से गुजारिश है कि {month} की रकम जल्द से जल्द भेजें:*',
      'share_report': 'रिपोर्ट शेयर करें',
      'select_what_to_share': 'चुनें कि आप क्या शेयर करना चाहते हैं',
      'full_report': 'पूरी रिपोर्ट',
      'full_report_description': 'सभी लेन-देन और खुलासा शामिल है',
      'non_payers_list': 'गैर देने वालों की फेहरिस्त',
      'non_payers_description':
          'उन अरकान की फेहरिस्त जिन्होंने अभी तक अदायगी नहीं की है',
      'cancel': 'रद्द करें',
      'share': 'शेयर करें',

      // Premium upgrade dialog
      'premium_title': 'प्रीमियम अपग्रेड',
      'premium_description': 'अपने मस्जिद के इंतजाम को बेहतर बनाएं',
      'premium_feature_charts': 'उन्नत चार्ट और विज़ुअलाइज़ेशन',
      'premium_feature_reports': 'खूबसूरत डिज़ाइन की गई रिपोर्ट',
      'premium_feature_backup': 'तरजीही क्लाउड बैकअप',
      'premium_feature_adfree': 'इश्तिहार से पाक तजुर्बा',
      'maybe_later': 'शायद बाद में',
      'upgrade_now': 'अभी अपग्रेड करें',

      // Add missing settings translations
      'font_size': 'फॉन्ट साइज़',
      'accent_color': 'एक्सेंट कलर',
      'version': 'वर्शन',
      'developed_by': 'डेवलपर',
      'secure_code': 'सुरक्षित कोड',
      'code_copied': 'सुरक्षित कोड क्लिपबोर्ड पर कॉपी किया गया',
      'offline_backup': 'ऑफलाइन बैकअप',
      'create_offline_backup': 'अपने डेटा का ऑफलाइन बैकअप बनाएं',
      'change_language': 'जुबान बदलने',
    },
    'ur': {
      // Dashboard and main screens
      'dashboard': 'ڈیش بورڈ',
      'accounts': 'اکاؤنٹس',
      'summary': 'خلاصہ',
      'reports': 'رپورٹس',
      'settings': 'ترتیبات',

      // Navigation items
      'manage_accounts': 'اکاؤنٹس کا انتظام کریں',
      'manage_payers': 'ادا کرنے والوں کا انتظام کریں',
      'manage_expense_categories': 'اخراجات کی اقسام کا انتظام کریں',
      'admin_panel': 'ایڈمن پینل',
      'go_premium': 'پریمیم حاصل کریں',

      // Settings screen
      'appearance_settings': 'ظاہری ترتیبات',
      'language_settings': 'زبان کی ترتیبات',
      'report_settings': 'رپورٹ کی ترتیبات',
      'theme_settings': 'تھیم کی ترتیبات',
      'data_recovery': 'ڈیٹا کی بازیابی',
      'contact_developer': 'ڈویلپر سے رابطہ کریں',
      'buy_me_coffee': 'مجھے کافی کھلائیں',
      'about_app': 'ایپ کے بارے میں',

      // Actions & buttons
      'add': 'شامل کریں',
      'edit': 'ترمیم کریں',
      'delete': 'حذف کریں',
      'save': 'محفوظ کریں',
      'cancel': 'منسوخ کریں',
      'confirm': 'تصدیق کریں',
      'close': 'بند کریں',
      'view_pdf': 'پی ڈی ایف دیکھیں',
      'save_pdf': 'پی ڈی ایف محفوظ کریں',
      'view_reports_analysis': 'رپورٹ س کا تجزیہ دیکھیں',
      'share_report': 'رپورٹ شیئر کریں',

      // Summary screen
      'total_income': 'کل آمدنی',
      'total_deductions': 'کل کٹوتیاں',
      'total_savings': 'کل بچت',
      'this_month': 'اس مہینے',
      'last_month': 'پچھلے مہینے',
      'total_balance': 'کل بیلنس',
      'recent_transactions': 'حالیہ لین دین',
      'recent_deductions': 'حالیہ کٹوتیاں',
      'unknown_payer': 'نامعلوم ادا کرنے والا',

      // Transaction related
      'income': 'آمدنی',
      'expense': 'آمدنی',
      'deduction': 'کٹوتی',
      'transaction': 'لین دین',
      'payer': 'آدا کرنے والا',
      'category': 'آمدنی',
      'amount': 'رقم',
      'date': 'تاریخ',
      'description': 'تفصیل',

      // Reports
      'report_information': 'رپورٹ کی معلومات',
      'select_month': 'مہینہ منتخب کریں',
      'pending_payments': 'زیر التواء ادائیگیاں',
      'report_information_description':
          'رپورٹس کو سیدھا دیکھا جا سکتا ہے یا اپنے دستاویز کے ڈاؤن لوڈ فولڈر میں سڑھا جا سکتا ہے۔ آپ سیڈڈ رپورٹس کو اپنے فائل ایکسپلورر کے مدد سے دستیاب کر سکتے ہیں۔',

      // UI elements
      'customize_app_look': 'ایپ کی ظاہری شکل کو اپنی مرضی کے مطابق بنائیں',
      'change_language': 'ایپ کی زبان تبدیل کریں',
      'configure_report': 'رپورٹ عنوان اور فارمیٹ ترتیب دیں',
      'switch_theme': 'لائٹ اور ڈارک موڈ کے درمیان سوئچ کریں',
      'backup_restore': 'ڈیٹا کا بیک اپ یا بحالی کریں',
      'get_technical_help': 'تکنیکی مدد حاصل کریں',
      'support_development': 'اس ایپ کی ترقی کی حمایت کریں',
      'learn_more': 'مسجد ایز کے بارے میں مزید جانیں',
      'unlock_premium': 'خصوصی خصوصیات کو انلاک کریں اور اشتہارات ہٹائیں',

      // New keys
      'quick_access': 'فوری رسائی',
      'data': 'ڈیٹا',
      'cloud_database': 'کلاؤڈ ڈیٹا بیس',
      'sync_data': 'ڈیٹا سینک کریں',
      'language_information': 'زبان کی معلومات',
      'select_language': 'زبان منتخب کریں',
      'items_count': '{count} آئٹمز',
      'payers_list': 'آدا کرنے والوں کی فہرست',
      'categories_list': 'آمدنی کی فہرست',
      'no_payers_yet': 'ابھی تک کوئی آدا کرنے والا نہیں',
      'no_categories_yet': 'ابھی تک کوئی آمدنی نہیں',
      'add_payer_to_get_started':
          'شروع کرنے کے لیے ایک نیا آدا کرنے والا شامل کریں',
      'add_category_to_get_started': 'شروع کرنے کے لیے ایک نئی آمدنی شامل کریں',
      'enter_payer_name': 'آدا کرنے والے کا نام درج کریں',
      'enter_category_name': 'آمدنی کا نام درج کریں',
      'please_enter_payer_name': 'براہ کرم آدا کرنے والے کا نام درج کریں',
      'please_enter_category_name': 'براہ کرم آمدنی کا نام درج کریں',
      'add_payer': 'آدا کرنے والا شامل کریں',
      'add_category': 'آمدنی شامل کریں',
      'payer_added_successfully': 'آدا کرنے والا کامیابی سے شامل کر دیا گیا',
      'category_added_successfully': 'آمدنی کامیابی سے شامل کر دی گئی',
      'payer_deleted_successfully': 'آدا کرنے والا کامیابی سے حذف کر دیا گیا',
      'category_deleted_successfully': 'آمدنی کامیابی سے حذف کر دی گئی',
      'error_unique_payer_name': 'غلطی: آدا کرنے والے کا نام منفرد ہونا چاہیے',
      'error_unique_category_name': 'غلطی: آمدنی کا نام منفرد ہونا چاہیے',
      'error_deleting_payer': 'آدا کرنے والے کو حذف کرنے میں غلطی',
      'error_deleting_category': 'آمدنی کو حذف کرنے میں غلطی',
      'confirm_delete_payer': 'کیا آپ واقعی "{name}" کو حذف کرنا چاہتے ہیں؟',
      'confirm_delete_category': 'کیا آپ واقعی "{name}" کو حذف کرنا چاہتے ہیں؟',

      // Manager screen
      'add_income': 'آمدنی شامل کریں',
      'add_deduction': 'کٹوتی شامل کریں',
      'select_payer': 'آدا کرنے والا منتخب کریں',
      'select_category': 'آمدنی منتخب کریں',
      'enter_amount': 'رقم درج کریں',
      'enter_deduction_amount': 'کٹوتی کی رقم درج کریں',
      'selected_date': 'منتخب کردہ تاریخ',
      'add_amount': 'رقم شامل کریں',
      'deduct_amount': 'رقم کاٹیں',
      'please_select_payer': 'براہ کرم ایک آدا کرنے والا منتخب کریں',
      'please_select_category': 'براہ کرم ایک آمدنی منتخب کریں',
      'please_enter_amount': 'براہ کرم ایک رقم درج کریں',
      'please_enter_valid_number': 'براہ کرم ایک درست نمبر درج کریں',

      // Role-based access translations
      'manager_role': 'مونیجر',
      'viewer_role': 'دیکھنے والا',
      'access_denied': 'اعتراض سے پاس آبھی ہو چکا',
      'manager_only': 'یہ خصوصیت صرف مونیجروں کے لئے موجود ہے',
      'insufficient_permissions': 'آپ کے پاس اس کام کرنے کی اجازت نہیں ہے',

      // Language settings
      'language_changed': 'زبان کامیابی سے تبدیل ہو گئی',
      'language_change_failed':
          'زبان تبدیل کرنے میں ناکام۔ براہ کرم دوبارہ کوشش کریں।',
      'language_info_description':
          'آپ کی زبان تبدیل کرتی ہے۔ درستگی کے لئے نمبرز، تاریخوں اور کرنسی کے نشانات تبدیل نہیں ہوں گے۔',
      'select_urdu_font': 'اردو فونٹ منتخب کریں',

      // Reports screen additional translations
      'currency_label': 'کرنسی: {symbol}',
      'transactions_copied': 'لین دین کلپ بورڈ پر کاپی ہو گئے!',
      'monthly_report_title': '{month} {year} حساب 📊',
      'income_section': 'آمدنی 📥',
      'expense_section': 'آمدنی 🛒',
      'summary_section': 'خلاصہ',
      'income_emoji': 'آمدنی💰',
      'expense_emoji': 'آمدنی💸',
      'savings_emoji': 'آمدنی💵',
      'pending_payment_request':
          '*درج ذیل افراد سے گزارش ہے کہ {month} کی رقم جلد از جلد بھیجیں:*',
      'share_report': 'رپورٹ شیئر کریں',
      'select_what_to_share': 'منتخب کریں کہ آپ کیا شیئر کرنا چاہتے ہیں',
      'full_report': 'مکمل رپورٹ',
      'full_report_description': 'تمام لین دین اور خلاصہ شامل ہے',
      'non_payers_list': 'غیر آدا کنندگان کی فہرست',
      'non_payers_description':
          'ان اراکین کی فہرست جنہوں نے ابھی تک ادائیگی نہیں کی ہے',
      'cancel': 'منسوخ کریں',
      'share': 'شیئر کریں',

      // Premium upgrade dialog
      'premium_title': 'پریمیم اپ گریڈ',
      'premium_description': 'اپنے مسجد کے انتظام کو بہتر بنائیں',
      'premium_feature_charts': 'اعلی درجے کے چارٹ اور ویژولائزیشن',
      'premium_feature_reports': 'ذوق بخت ڈیزائن کردہ رپورٹس',
      'premium_feature_backup': 'ترجیحی کلاؤڈ بیک اپ',
      'premium_feature_adfree': 'بیجود پاک تجربہ',
      'maybe_later': 'شاید بعد میں',
      'upgrade_now': 'ابھی اپ گریڈ کریں',

      // Add missing settings translations
      'font_size': 'فونٹ سائز',
      'accent_color': 'ایکسینٹ کلر',
      'version': 'ورژن',
      'developed_by': 'ڈویلپر',
      'secure_code': 'سیکیور کوڈ',
      'code_copied': 'سیکیور کوڈ کلپ بورڈ پر کاپی ہو گیا',
      'offline_backup': 'آف لائن بیک اپ',
      'create_offline_backup': 'اپنے ڈیٹا کا آف لائن بیک اپ بنائیں',
      'change_language': 'زبان تبدیل کریں',
    },
    'bn': {
      // Dashboard and main screens
      'dashboard': 'ড্যাশবোর্ড',
      'accounts': 'অ্যাকাউন্ট',
      'summary': 'সারাংশ',
      'reports': 'রিপোর্ট',
      'settings': 'সেটিংস',

      // Navigation items
      'manage_accounts': 'অ্যাকাউন্ট পরিচালনা করুন',
      'manage_payers': 'দাতা পরিচালনা করুন',
      'manage_expense_categories': 'ব্যয়ের বিভাগ পরিচালনা করুন',
      'admin_panel': 'অ্যাডমিন প্যানেল',
      'go_premium': 'প্রিমিয়ামে যান',

      // Settings screen
      'appearance_settings': 'চেহারা সেটিংস',
      'language_settings': 'ভাষা সেটিংস',
      'report_settings': 'রিপোর্ট সেটিংস',
      'theme_settings': 'থিম সেটিংস',
      'data_recovery': 'ডেটা পুনরুদ্ধার',
      'contact_developer': 'ডেভেলপারের সাথে যোগাযোগ করুন',
      'buy_me_coffee': 'আমাকে কফি কিনে দিন',
      'about_app': 'অ্যাপ সম্পর্কে',

      // Actions & buttons
      'add': 'যোগ করুন',
      'edit': 'সম্পাদনা করুন',
      'delete': 'মুছে ফেলুন',
      'save': 'সংরক্ষণ করুন',
      'cancel': 'বাতিল করুন',
      'confirm': 'নিশ্চিত করুন',
      'close': 'বন্ধ করুন',
      'view_pdf': 'পিডিএফ দেখুন',
      'save_pdf': 'পিডিএফ সংরক্ষণ করুন',
      'view_reports_analysis': 'রিপোর্ট বিশ্লেষণ দেখুন',
      'share_report': 'রিপোর্ট শেয়ার করুন',

      // Summary screen
      'total_income': 'মোট আয়',
      'total_deductions': 'মোট ব্যয়',
      'total_savings': 'মোট সঞ্চয়',
      'this_month': 'এই মাস',
      'last_month': 'গত মাস',
      'total_balance': 'মোট ব্যালেন্স',
      'recent_transactions': 'সাম্প্রতিক লেনদেন',
      'recent_deductions': 'সাম্প্রতিক ব্যয়',
      'unknown_payer': 'অজানা দাতা',

      // Transaction related
      'income': 'আয়',
      'expense': 'ব্যয়',
      'deduction': 'কাটা',
      'transaction': 'লেনদেন',
      'payer': 'দাতা',
      'category': 'বিভাগ',
      'amount': 'পরিমাণ',
      'date': 'তারিখ',
      'description': 'বিবরণ',

      // Reports
      'report_information': 'রিপোর্ট তথ্য',
      'select_month': 'মাস নির্বাচন করুন',
      'pending_payments': 'বকেয়া পেমেন্ট',
      'report_information_description':
          'রিপোর্ট সরাসরি দেখা যাবে বা আপনার ডিভাইসের ডাউনলোড ফোল্ডার মাধ্যমে সংরক্ষণ করা যাবে। আপনি ফাইল এক্সপ্লোরার মাধ্যমে সংরক্ষিত রিপোর্ট অ্যাক্সেস করতে পারবেন।',

      // UI elements
      'customize_app_look': 'অ্যাপের চেহারা কাস্টমাইজ করুন',
      'change_language': 'অ্যাপের ভাষা পরিবর্তন করুন',
      'configure_report': 'রিপোর্ট শিরোনাম এবং ফরম্যাট কনফিগার করুন',
      'switch_theme': 'লাইট এবং ডার্ক মোডের মধ্যে পরিবর্তন করুন',
      'backup_restore': 'ডেটা ব্যাকআপ বা পুনরুদ্ধার করুন',
      'get_technical_help': 'প্রযুক্তিগত সাহায্য পান',
      'support_development': 'এই অ্যাপের উন্নয়ন সমর্থন করুন',
      'learn_more': 'মসজিদ ইজ সম্পর্কে আরও জানুন',
      'unlock_premium': 'এক্সক্লুসিভ ফিচার আনলক করুন এবং বিজ্ঞাপন সরান',

      // New keys
      'quick_access': 'দ্রুত অ্যাক্সেস',
      'data': 'ডেটা',
      'cloud_database': 'ক্লাউড ডাটাবেস',
      'sync_data': 'ডেটা সিঙ্ক করুন',
      'language_information': 'ভাষা তথ্য',
      'select_language': 'ভাষা নির্বাচন করুন',
      'items_count': '{count} আইটেম',
      'payers_list': 'দাতাদের তালিকা',
      'categories_list': 'বিভাগের তালিকা',
      'no_payers_yet': 'এখনো কোন দাতা নেই',
      'no_categories_yet': 'এখনো কোন বিভাগ নেই',
      'add_payer_to_get_started': 'শুরু করতে একটি নতুন দাতা যোগ করুন',
      'add_category_to_get_started': 'শুরু করতে একটি নতুন বিভাগ যোগ করুন',
      'enter_payer_name': 'দাতার নাম লিখুন',
      'enter_category_name': 'বিভাগের নাম লিখুন',
      'please_enter_payer_name': 'অনুগ্রহ করে দাতার নাম লিখুন',
      'please_enter_category_name': 'অনুগ্রহ করে বিভাগের নাম লিখুন',
      'add_payer': 'দাতা যোগ করুন',
      'add_category': 'বিভাগ যোগ করুন',
      'payer_added_successfully': 'দাতা সফলভাবে যোগ করা হয়েছে',
      'category_added_successfully': 'বিভাগ সফলভাবে যোগ করা হয়েছে',
      'payer_deleted_successfully': 'দাতা সফলভাবে মুছে ফেলা হয়েছে',
      'category_deleted_successfully': 'বিভাগ সফলভাবে মুছে ফেলা হয়েছে',
      'error_unique_payer_name': 'ত্রুটি: দাতার নাম অনন্য হতে হবে',
      'error_unique_category_name': 'ত্রুটি: বিভাগের নাম অনন্য হতে হবে',
      'error_deleting_payer': 'দাতা মুছতে ত্রুটি',
      'error_deleting_category': 'বিভাগ মুছতে ত্রুটি',
      'confirm_delete_payer': 'আপনি কি নিশ্চিত যে আপনি "{name}" মুছতে চান?',
      'confirm_delete_category': 'আপনি কি নিশ্চিত যে আপনি "{name}" মুছতে চান?',

      // Manager screen
      'add_income': 'আয় যোগ করুন',
      'add_deduction': 'ব্যয় যোগ করুন',
      'select_payer': 'দাতা নির্বাচন করুন',
      'select_category': 'বিভাগ নির্বাচন করুন',
      'enter_amount': 'পরিমাণ লিখুন',
      'enter_deduction_amount': 'ব্যয়ের পরিমাণ লিখুন',
      'selected_date': 'নির্বাচিত তারিখ',
      'add_amount': 'পরিমাণ যোগ করুন',
      'deduct_amount': 'পরিমাণ কাটুন',
      'please_select_payer': 'অনুগ্রহ করে একজন দাতা নির্বাচন করুন',
      'please_select_category': 'অনুগ্রহ করে একটি বিভাগ নির্বাচন করুন',
      'please_enter_amount': 'অনুগ্রহ করে একটি পরিমাণ লিখুন',
      'please_enter_valid_number': 'অনুগ্রহ করে একটি বৈধ সংখ্যা লিখুন',

      // Role-based access translations
      'manager_role': 'ম্যানেজার',
      'viewer_role': 'দর্শক',
      'access_denied': 'অ্যাক্সেস অস্বীকার করা হয়েছে',
      'manager_only': 'এই ফিচারটি শুধুমাত্র ম্যানেজারদের জন্য উপলব্ধ',
      'insufficient_permissions': 'আপনার এই কাজ করার অনুমতি নেই',

      // Language settings
      'language_changed': 'ভাষা সফলভাবে পরিবর্তন করা হয়েছে',
      'language_change_failed':
          'ভাষা পরিবর্তন করতে ব্যর্থ হয়েছে। অনুগ্রহ করে আবার চেষ্টা করুন।',
      'language_info_description':
          'এই সেটিং অ্যাপ ইন্টারফেসের ভাষা পরিবর্তন করে। নির্ভুলতার জন্য সংখ্যা, তারিখ এবং মুদ্রা চিহ্ন অপরিবর্তিত থাকবে।',

      // Reports screen additional translations
      'currency_label': 'মুদ্রা: {symbol}',
      'transactions_copied': 'লেনদেন ক্লিপবোর্ড पर কপি করা হয়েছে!',
      'monthly_report_title': '{month} {year} রিপোর্ট 📊',
      'income_section': 'আয় 📥',
      'expense_section': 'ব্যয় 🛒',
      'summary_section': 'সারাংশ',
      'income_emoji': 'আয়💰',
      'expense_emoji': 'ব্যয়💸',
      'savings_emoji': 'সঞ্চয় 💵',
      'pending_payment_request':
          '*অনুগ্রহ করে নিম্নলিখিত ব্যক্তিদের {month} মাসের পেমেন্ট যত তাড়াতাড়ি সম্ভব পাঠাতে বলুন:*',
      'share_report': 'রিপোর্ট শেয়ার করুন',
      'select_what_to_share': 'আপনি কি শেয়ার করতে চান তা নির্বাচন করুন',
      'full_report': 'সম্পূর্ণ রিপোর্ট',
      'full_report_description': 'সমস্ত লেনদেন এবং সারাংশ অন্তর্ভুক্ত',
      'non_payers_list': 'অদাতাদের তালিকা',
      'non_payers_description': 'যারা এখনও পেমেন্ট করেনি তাদের সদস্যদের তালিকা',
      'cancel': 'বাতিল করুন',
      'share': 'শেয়ার করুন',

      // Premium upgrade dialog
      'premium_title': 'প্রিমিয়াম আপগ্রেড',
      'premium_description': 'আপনার মসজিদ ব্যবস্থাপনা উন্নত করুন',
      'premium_feature_charts': 'উন্নত চার্ট এবং ভিজ্যুয়ালাইজেশন',
      'premium_feature_reports': 'সুন্দর ডিজাইন করা রিপোর্ট',
      'premium_feature_backup': 'অগ্রাধিকার ক্লাউড ব্যাকআপ',
      'premium_feature_adfree': 'বিজ্ঞাপন-মুক্ত অভিজ্ঞতা',
      'maybe_later': 'পরবর্তীতে',
      'upgrade_now': 'এখনই আপগ্রেড করুন',

      // Add missing settings translations
      'font_size': 'ফন্ট সাইজ',
      'accent_color': 'এক্সিন্ট কালার',
      'version': 'ভার্সন',
      'developed_by': 'ডেভেলপার',
      'secure_code': 'সিকিউর কোড',
      'code_copied': 'সিকিউর কোড ক্লিপবোর্ডে কপি করা হয়েছে',
      'offline_backup': 'অফলাইন ব্যাকআপ',
      'create_offline_backup': 'আপনার ডেটার অফলাইন ব্যাকআপ তৈরি করুন',
      'change_language': 'ভাষা পরিবর্তন করা',
    },
  };
}
