import 'package:flutter/material.dart';
import 'package:logging/logging.dart' as logging;
import 'payer_screen.dart';
import 'category_screen.dart';
import 'admin_screen.dart';
import 'cloud_database_screen.dart';
import '../services/data_recovery_service.dart';
import '../services/database_service.dart';
import '../services/google_sheets_export_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import 'premium_screen.dart';
import 'language_settings_screen.dart';
import '../widgets/translated_text.dart';
import '../services/language_service.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../services/installation_date_service.dart';

class ManagerSettingsScreen extends StatefulWidget {
  const ManagerSettingsScreen({Key? key}) : super(key: key);

  @override
  State<ManagerSettingsScreen> createState() => _ManagerSettingsScreenState();
}

class _ManagerSettingsScreenState extends State<ManagerSettingsScreen>
    with SingleTickerProviderStateMixin {
  static final _logger = logging.Logger('ManagerSettingsScreen');
  final bool _isDarkMode = false;
  late TabController _tabController;
  final TextEditingController _reportTitleController = TextEditingController();
  StreamSubscription<String>? _languageChangeSubscription;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      setState(() {}); // This will rebuild the widget when tab changes
    });
    // Subscribe to language changes
    _languageChangeSubscription =
        LanguageService.instance.onLanguageChanged.listen((_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _reportTitleController.dispose();
    _languageChangeSubscription?.cancel();
    super.dispose();
  }

  void _navigateToScreen(BuildContext context, String buttonName) {
    switch (buttonName) {
      case 'PAYER':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const PayerScreen()),
        );
        break;
      case 'CATEGORIES':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const CategoryScreen()),
        );
        break;
      case 'ADMIN':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const AdminScreen()),
        );
        break;
      case 'CLOUD DATABASE SETTING':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const CloudDatabaseScreen()),
        );
        break;
      case 'BUY_PREMIUM':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const PremiumScreen()),
        );
        break;
      case 'LANGUAGE':
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => const LanguageSettingsScreen()),
        );
        break;
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$buttonName coming soon...')),
        );
    }
  }

  Future<void> _handleDataRecovery(BuildContext context, bool isBackup) async {
    _logger.info('Starting data recovery process. isBackup: $isBackup');
    try {
      // Show loading indicator
      _logger.info('Showing loading indicator...');
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      _logger.info('Initializing Google Sheets service...');
      final sheetsService = GoogleSheetsExportService();
      await sheetsService.initialize();
      _logger.info('Google Sheets service initialized');

      _logger.info('Creating DataRecoveryService...');
      final recoveryService = DataRecoveryService(
        databaseService: DatabaseService.instance,
        sheetsService: sheetsService,
      );
      final prefs = await SharedPreferences.getInstance();
      final mosqueName = prefs.getString('masjid_name') ?? '';
      final securityKey = prefs.getString('security_key_$mosqueName') ?? '';
      _logger.info('DataRecoveryService created');

      if (isBackup) {
        _logger.info('Starting backup process...');
        await recoveryService.createRecoveryData(securityKey);
        _logger.info('Backup completed Successfully');

        if (!context.mounted) return;

        // Close loading dialog
        _logger.info('Closing loading dialog...');
        Navigator.of(context).pop();

        _logger.info('Showing success message...');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Data backup created Successfully'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 5),
          ),
        );
      } else {
        // Get mosque name and spreadsheet ID
        final spreadsheetId = prefs.getString('mosque_sheet_$mosqueName');

        if (mosqueName.isEmpty ||
            spreadsheetId == null ||
            spreadsheetId.isEmpty) {
          _logger.warning('Missing mosque name or spreadsheet ID');
          if (!context.mounted) return;
          Navigator.of(context).pop(); // Close loading dialog
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Missing mosque name or spreadsheet ID. Please complete setup first.'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 5),
            ),
          );
          return;
        }

        // Show confirmation dialog before restoring
        if (!context.mounted) return;
        _logger.info('Closing loading dialog for confirmation...');
        Navigator.of(context).pop(); // Close loading dialog

        _logger.info('Showing confirmation dialog...');
        final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Confirm Data Restoration'),
            content: const Text(
                'This will replace all your current data with the backup data. '
                'This action cannot be undone. Are you sure you want to continue?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Restore'),
              ),
            ],
          ),
        );

        if (confirm != true) {
          _logger.info('User cancelled restoration');
          return;
        }

        // Show loading indicator again
        _logger.info('Showing loading indicator for restoration...');
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(),
          ),
        );

        _logger.info(
            'Starting data restoration with spreadsheet ID: $spreadsheetId');
        await recoveryService.restoreFromRecoveryData(
            spreadsheetId, securityKey);
        _logger.info('Data restoration completed');

        if (!context.mounted) return;

        // Close loading dialog
        _logger.info('Closing loading dialog...');
        Navigator.of(context).pop();

        _logger.info('Showing success message...');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Data restored Successfully. Please restart the app to see changes.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 5),
          ),
        );
      }
    } catch (e, stackTrace) {
      _logger.severe('Error during data recovery process', e, stackTrace);

      // Close loading dialog if open
      if (context.mounted && Navigator.of(context).canPop()) {
        _logger.info('Closing loading dialog due to error...');
        Navigator.of(context).pop();
      }

      if (!context.mounted) return;
      _logger.info('Showing error message...');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 10),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          Container(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: SafeArea(
              child: Column(
                children: [
                  Container(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                    decoration: BoxDecoration(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      borderRadius: BorderRadius.circular(1),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: _buildCustomTab(
                            0,
                            'Quick Access',
                            Icons.dashboard_outlined,
                            Colors.blue,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildCustomTab(
                            1,
                            'Settings',
                            Icons.settings_outlined,
                            Colors.green,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildCustomTab(
                            2,
                            'Data',
                            Icons.storage_outlined,
                            Colors.purple,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Container(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildQuickAccessTab(),
                  _buildSettingsTab(),
                  _buildDataTab(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAccessTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildActionCard(
            'manage_payers',
            'manage_payers',
            Icons.people_outline,
            Colors.blue,
            () => _navigateToScreen(context, 'PAYER'),
          ),
          const SizedBox(height: 16),
          _buildActionCard(
            'manage_expense_categories',
            'manage_expense_categories',
            Icons.category_outlined,
            Colors.green,
            () => _navigateToScreen(context, 'CATEGORIES'),
          ),
          const SizedBox(height: 16),
          _buildActionCard(
            'admin_panel',
            'admin_panel',
            Icons.admin_panel_settings_outlined,
            Colors.purple,
            () => _navigateToScreen(context, 'ADMIN'),
          ),
          const SizedBox(height: 16),
          // Premium card with 3-month notice
          Stack(
            clipBehavior: Clip.none,
            children: [
              _buildActionCard(
                'go_premium',
                'unlock_premium',
                Icons.workspace_premium_outlined,
                Colors.amber,
                () => _navigateToScreen(context, 'BUY_PREMIUM'),
              ),
              Positioned(
                top: -10,
                right: 20,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    '3 months free',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildActionCard(
            'appearance_settings',
            'customize_app_look',
            Icons.palette_outlined,
            Colors.orange,
            () => _navigateToScreen(context, 'APPEARANCE'),
          ),
          const SizedBox(height: 16),
          _buildActionCard(
            'language_settings',
            'change_language',
            Icons.language_outlined,
            Colors.indigo,
            () => _navigateToScreen(context, 'LANGUAGE'),
          ),
          const SizedBox(height: 16),
          _buildActionCard(
            'report_settings',
            'configure_report',
            Icons.description_outlined,
            Colors.teal,
            () => _navigateToScreen(context, 'REPORT'),
          ),
          const SizedBox(height: 16),
          _buildActionCard(
            'theme_settings',
            'switch_theme',
            Icons.dark_mode_outlined,
            Colors.deepPurple,
            () => _navigateToScreen(context, 'THEME'),
          ),
          const SizedBox(height: 16),
          _buildActionCard(
            'data_recovery',
            'backup_restore',
            Icons.backup_outlined,
            Colors.teal,
            () => _handleDataRecovery(context, true),
          ),
          const SizedBox(height: 16),
          _buildActionCard(
            'contact_developer',
            'get_technical_help',
            Icons.support_agent,
            Colors.blue,
            () => _showDeveloperContact(context),
          ),
          const SizedBox(height: 16),
          _buildActionCard(
            'buy_me_coffee',
            'support_development',
            Icons.coffee,
            Colors.brown,
            () => _showDonationPopup(context),
          ),
          const SizedBox(height: 16),
          _buildActionCard(
            'about_app',
            'learn_more',
            Icons.info_outline,
            Colors.blue,
            () => _showAboutAppDialog(context),
          ),
          // Invisible testing area - requires long press (30 seconds) to enable ads
          Align(
            alignment: Alignment.center,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: GestureDetector(
                onLongPress: () {
                  // Show a countdown indicator
                  int remainingSeconds = 30;
                  final scaffoldMessenger = ScaffoldMessenger.of(context);

                  // Show initial message
                  scaffoldMessenger.showSnackBar(
                    SnackBar(
                      content: Text(
                          'Hold for $remainingSeconds seconds to enable ads...'),
                      duration: const Duration(seconds: 2),
                    ),
                  );

                  // Create a timer that updates every second
                  Timer.periodic(const Duration(seconds: 1), (timer) async {
                    remainingSeconds--;

                    // Show progress at intervals
                    if (remainingSeconds % 5 == 0 && remainingSeconds > 0) {
                      scaffoldMessenger.clearSnackBars();
                      scaffoldMessenger.showSnackBar(
                        SnackBar(
                          content: Text(
                              'Keep holding: $remainingSeconds seconds remaining...'),
                          duration: const Duration(milliseconds: 800),
                        ),
                      );
                    }

                    // Time completed - activate ads
                    if (remainingSeconds <= 0) {
                      timer.cancel();

                      // Force ads to appear by setting installation date to 3 months ago
                      await InstallationDateService()
                          .forceThreeMonthsPassedForTesting();

                      // Show success message
                      scaffoldMessenger.clearSnackBars();
                      scaffoldMessenger.showSnackBar(
                        const SnackBar(
                          content: Text(
                              'Ads enabled! App will now show ads as if 3 months have passed.'),
                          backgroundColor: Colors.green,
                          duration: Duration(seconds: 3),
                        ),
                      );
                    }
                  });
                },
                child: Container(
                  width: 100,
                  height: 30,
                  color: Colors.transparent, // Completely invisible
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildActionCard(
            'cloud_database',
            'cloud_database',
            Icons.cloud_outlined,
            Colors.orange,
            () => _navigateToScreen(context, 'CLOUD DATABASE SETTING'),
          ),
          const SizedBox(height: 16),
          _buildActionCard(
            'sync_data',
            'sync_data',
            Icons.sync_outlined,
            Colors.teal,
            () => _navigateToScreen(context, 'SYNC'),
          ),
          const SizedBox(height: 16),
          _buildActionCard(
            'offline_backup',
            'create_offline_backup',
            Icons.save_alt_outlined,
            Colors.green,
            () => _handleOfflineBackup(context),
          ),
          const SizedBox(height: 16),
          _buildActionCard(
            'contact_developer',
            'get_technical_help',
            Icons.support_agent,
            Colors.blue,
            () => _showDeveloperContact(context),
          ),
          const SizedBox(height: 16),
          _buildActionCard(
            'buy_me_coffee',
            'support_development',
            Icons.coffee,
            Colors.brown,
            () => _showDonationPopup(context),
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

  Widget _buildActionCard(String title, String subtitle, IconData icon,
      Color color, VoidCallback onTap) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TranslatedText(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    TranslatedText(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, color: Colors.grey[400], size: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingCard(String title, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
          ...children,
        ],
      ),
    );
  }

  Widget _buildSettingTile(
    String title,
    String subtitle,
    IconData icon, {
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, color: Colors.grey[600]),
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
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCustomTab(int index, String title, IconData icon, Color color) {
    bool isSelected = _tabController.index == index;
    String translationKey;
    switch (index) {
      case 0:
        translationKey = 'quick_access';
        break;
      case 1:
        translationKey = 'settings';
        break;
      case 2:
        translationKey = 'data';
        break;
      default:
        translationKey = title;
    }

    return GestureDetector(
      onTap: () => _tabController.animateTo(index),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withAlpha(26) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.grey.withAlpha(77),
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? color : Colors.grey,
              size: 20,
            ),
            const SizedBox(height: 4),
            TranslatedText(
              translationKey,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? color : Colors.grey,
              ),
            ),
          ],
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
              'support_development',
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

  void _showAboutAppDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.info_outline, color: Colors.blue),
            SizedBox(width: 8),
            TranslatedText('about_app'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Version 1.0.0',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            const TranslatedText(
              'learn_more',
              style: TextStyle(
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            const TranslatedText(
              'Key Features:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            _buildFeatureItem('income'.tr),
            _buildFeatureItem('expense'.tr),
            _buildFeatureItem('reports'.tr),
            _buildFeatureItem('data_recovery'.tr),
            _buildFeatureItem('language_settings'.tr),
            const SizedBox(height: 16),
            const Text(
              'Developed by Ajaj Abbas Ali',
              style: TextStyle(
                fontSize: 14,
                fontStyle: FontStyle.italic,
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

  Widget _buildFeatureItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          color: Colors.black87,
        ),
      ),
    );
  }

  Future<void> _handleOfflineBackup(BuildContext context) async {
    _logger.info('Starting offline backup process...');
    try {
      // Show loading indicator
      _logger.info('Showing loading indicator...');
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      _logger.info('Initializing database service...');
      final databaseService = DatabaseService.instance;
      final prefs = await SharedPreferences.getInstance();
      final mosqueName = prefs.getString('masjid_name') ?? '';
      final securityKey = prefs.getString('security_key_$mosqueName') ?? '';

      if (mosqueName.isEmpty || securityKey.isEmpty) {
        _logger.warning('Missing mosque name or security key');
        if (!context.mounted) return;
        Navigator.of(context).pop(); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Missing mosque name or security key. Please complete setup first.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );
        return;
      }

      // Get data from all tables
      final payers = await databaseService.getAllPayers();
      final transactions = await databaseService.getAllTransactions();
      final categories = await databaseService.getAllCategories();

      // Convert data to JSON format
      final backupData = {
        'mosque_name': mosqueName,
        'security_key': securityKey,
        'timestamp': DateTime.now().toIso8601String(),
        'report_header': prefs.getString('report_header') ?? '',
        'payers': payers.map((p) => {'id': p.id, 'name': p.name}).toList(),
        'categories':
            categories.map((c) => {'id': c.id, 'name': c.name}).toList(),
        'transactions': transactions
            .map((t) => {
                  'id': t.id,
                  'payer_id': t.payerId,
                  'amount': t.amount,
                  'type': t.type.toString(),
                  'category': t.category,
                  'date': t.date.toIso8601String(),
                })
            .toList(),
      };

      // Convert to JSON string
      final jsonData = json.encode(backupData);

      // Get the downloads directory and create a Mosque_Fund subfolder (same as in reports_screen.dart)
      Directory? backupDir;
      if (Platform.isAndroid) {
        // For Android, use the downloads directory
        backupDir = Directory('/storage/emulated/0/Download');
        if (!await backupDir.exists()) {
          backupDir = await getExternalStorageDirectory();
        }
      } else {
        // For iOS, use the documents directory
        backupDir = await getApplicationDocumentsDirectory();
      }

      if (backupDir == null) {
        throw Exception('Could not access storage directory');
      }

      // Create Mosque_Fund subfolder
      final mosqueFundDir = Directory('${backupDir.path}/Mosque_Fund');
      if (!await mosqueFundDir.exists()) {
        await mosqueFundDir.create(recursive: true);
      }

      // Create a timestamp for the filename
      final now = DateTime.now();
      final timestamp =
          "${now.year}_${now.month.toString().padLeft(2, '0')}_${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}";
      final fileName = '${mosqueName}_Backup_$timestamp.json';
      final filePath = '${mosqueFundDir.path}/$fileName';

      // Write to file
      final file = File(filePath);
      await file.writeAsString(jsonData);

      // Close loading dialog
      if (!context.mounted) return;
      Navigator.of(context).pop();

      // Ask user if they want to share the file
      _logger.info('Showing share file dialog...');
      final shouldShare = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 8),
              Text('Backup Created'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Backup file created successfully at:',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                filePath,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Would you like to share this file now?',
                style: TextStyle(fontSize: 16),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('No'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Share'),
            ),
          ],
        ),
      );

      if (shouldShare == true && context.mounted) {
        // Share the file
        _logger.info('Sharing backup file...');
        await Share.shareXFiles(
          [XFile(filePath)],
          text: 'Mosque Ease Backup - $mosqueName',
          subject: 'Mosque Ease Backup File',
        );
      }
    } catch (e, stackTrace) {
      _logger.severe('Error during offline backup process', e, stackTrace);

      // Close loading dialog if open
      if (context.mounted && Navigator.of(context).canPop()) {
        _logger.info('Closing loading dialog due to error...');
        Navigator.of(context).pop();
      }

      if (!context.mounted) return;
      _logger.info('Showing error message...');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error creating backup: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 10),
        ),
      );
    }
  }
}
