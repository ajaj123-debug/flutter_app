import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logging/logging.dart' as logging;
import 'dart:io'; // For InternetAddress and SocketException
import 'manager_screen.dart'; // Accounts screen
import 'manager_settings_screen.dart'; // Settings screen
import 'role_selection_screen.dart';
import 'summary_screen.dart'; // Import the new summary screen
import 'reports_screen.dart'; // Import the new reports screen
import '../services/script_based_export_service.dart'; // Import the new service
import '../services/script_based_recovery_service.dart'; // Import the script-based recovery service
import '../services/direct_google_sheets_service.dart'; // Import the direct Google Sheets service
import '../services/database_service.dart';
import 'first_time_setup_screen.dart';
import 'premium_screen.dart';
import '../widgets/translated_text.dart';
import '../services/language_service.dart';
import 'dart:async';
import '../services/ad_service.dart'; // Import ad service
import 'dart:math';

class ManagerMainScreen extends StatefulWidget {
  const ManagerMainScreen({Key? key}) : super(key: key);

  @override
  State<ManagerMainScreen> createState() => _ManagerMainScreenState();
}

class _ManagerMainScreenState extends State<ManagerMainScreen>
    with SingleTickerProviderStateMixin {
  static final _logger = logging.Logger('ManagerMainScreen');
  int _selectedIndex = 1;
  bool _isExporting = false;
  AnimationController? _animationController;
  Animation<double>? _opacityAnimation;
  StreamSubscription<String>? _languageChangeSubscription;

  static const List<Widget> _widgetOptions = <Widget>[
    ManagerScreen(), // Index 0: Accounts
    SummaryScreen(), // Index 1: Summary
    ReportsScreen(), // Index 2: Reports
    ManagerSettingsScreen(), // Index 3: Settings
  ];

  @override
  void initState() {
    super.initState();
    // Initialize animation after a short delay to ensure widget is mounted
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _initAnimation();
      }
    });

    // Subscribe to language changes
    _languageChangeSubscription =
        LanguageService.instance.onLanguageChanged.listen((_) {
      if (mounted) {
        setState(() {});
      }
    });

    // Initialize and preload rewarded ads
    _initializeAds();

    // Reset export count if it's a new day
    _checkAndResetExportCount();
  }

  // Check if it's a new day and reset export count if needed
  Future<void> _checkAndResetExportCount() async {
    final prefs = await SharedPreferences.getInstance();
    final lastExportDate = prefs.getString('last_export_date');
    final today =
        DateTime.now().toString().substring(0, 10); // YYYY-MM-DD format

    if (lastExportDate != today) {
      // It's a new day, reset export count
      await prefs.setInt('daily_export_count', 0);
      await prefs.setString('last_export_date', today);
    }
  }

  // Initialize and preload ads
  Future<void> _initializeAds() async {
    try {
      final adService = AdService();
      await adService.initialize();
      await adService.loadRewardedAd();
    } catch (e) {
      _logger.warning('Error initializing ads: $e');
    }
  }

  void _initAnimation() {
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    _opacityAnimation =
        Tween<double>(begin: 0.3, end: 1.0).animate(_animationController!);
    // Start the animation
    _animationController!.repeat(reverse: true);
  }

  @override
  void dispose() {
    _animationController?.dispose();
    _languageChangeSubscription?.cancel();
    // Dispose of any loaded ads when the widget is removed
    AdService().disposeRewardedAd();
    super.dispose();
  }

  void _onItemTapped(int index) {
    // Check if trying to navigate to Summary (1) or Reports (2) tabs, which might need ad display
    if ((index == 1 || index == 2) && _selectedIndex != index) {
      _checkAdBeforeNavigating(index);
    } else {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  // Method to check if ads should be shown before navigating to premium features
  Future<void> _checkAdBeforeNavigating(int tabIndex) async {
    // Check if three months have passed
    final adService = AdService();
    final shouldShowAds = await adService.shouldShowAds();

    if (!shouldShowAds) {
      // If three months haven't passed yet, just navigate to the tab
      setState(() {
        _selectedIndex = tabIndex;
      });
      return;
    }

    // For tabs that normally require premium, check if the user has watched an ad today
    final prefs = await SharedPreferences.getInstance();
    final today =
        DateTime.now().toString().substring(0, 10); // YYYY-MM-DD format

    final String featureKey = tabIndex == 1 ? 'summary_tab' : 'reports_tab';
    final lastAdWatchDate = prefs.getString('tab_ad_watch_date_$featureKey');
    final adAlreadyWatchedToday = lastAdWatchDate == today;

    if (adAlreadyWatchedToday) {
      // If an ad was already watched today for this feature, allow access
      setState(() {
        _selectedIndex = tabIndex;
      });
      return;
    }

    // Check if a rewarded ad is available
    if (adService.isRewardedAdReady()) {
      // Show a dialog explaining the ad requirement
      final featureName = tabIndex == 1 ? 'Summary' : 'Reports';

      if (!mounted) return;

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: Text('Watch an Ad for $featureName'),
          content: Text(
            'After 3 months of free usage, you need to watch a short ad to access $featureName features. '
            'After watching the ad, you can use this feature without ads for the rest of the day.\n\n'
            'Upgrade to Premium to remove all ads permanently.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _showPremiumDialog(context);
              },
              child: const Text('View Premium'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Watch Ad'),
            ),
          ],
        ),
      ).then((shouldShowAd) async {
        if (shouldShowAd == true) {
          final bool rewardEarned = await adService.showRewardedAd(context);

          if (rewardEarned) {
            _logger
                .info('User earned reward for $featureKey, saving watch date');
            // Save the date when ad was watched for this tab
            await prefs.setString('tab_ad_watch_date_$featureKey', today);

            // Navigate to the tab
            if (mounted) {
              setState(() {
                _selectedIndex = tabIndex;
              });
            }
          } else {
            _logger.info('User did not earn reward for $featureKey');
            // Stay on the current tab
          }
        }
      });
    } else {
      // If no ad is available, allow access this time and preload for next time
      adService.loadRewardedAd();
      setState(() {
        _selectedIndex = tabIndex;
      });
    }
  }

  Future<void> _handleLogout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    // Clear all preferences
    await prefs.clear();
    // Reset first launch flag
    await prefs.setBool('first_launch', true);

    if (!context.mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => const RoleSelectionScreen(),
      ),
    );
  }

  Future<void> _exportToGoogleSheets() async {
    if (_isExporting) return;

    // Check daily export limit
    final prefs = await SharedPreferences.getInstance();
    final today =
        DateTime.now().toString().substring(0, 10); // YYYY-MM-DD format

    // Update last export date and count
    final lastExportDate = prefs.getString('last_export_date') ?? '';
    if (lastExportDate != today) {
      // It's a new day, reset export count
      await prefs.setInt('daily_export_count', 0);
      await prefs.setString('last_export_date', today);
    }

    // Get current export count
    int dailyExportCount = prefs.getInt('daily_export_count') ?? 0;

    // Check if export limit reached
    if (dailyExportCount >= 5) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Daily export limit reached (5/5). Try again tomorrow.'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }

    // Check internet connection first
    try {
      final result = await InternetAddress.lookup('google.com');
      if (result.isEmpty || result[0].rawAddress.isEmpty) {
        throw Exception('No internet connection available');
      }
    } on SocketException catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please check your internet connection and try again'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Check if ad already watched today
    final lastAdWatchDate = prefs.getString('last_ad_watch_date');
    bool adAlreadyWatchedToday = lastAdWatchDate == today;

    // Get the AdService
    final adService = AdService();

    // Check if ads should be shown based on installation date (3-month check)
    final shouldShowAds = await adService.shouldShowAds();

    // Only require watching an ad if 3 months have passed and no ad was watched today
    if (shouldShowAds &&
        !adAlreadyWatchedToday &&
        adService.isRewardedAdReady()) {
      // Show a dialog informing the user that they need to watch an ad once per day
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Watch an Ad'),
          content: const Text(
            'You need to watch a short ad once per day before exporting. After watching the ad, you can export data without ads for the rest of the day.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );

      final bool rewardEarned = await adService.showRewardedAd(context);

      if (rewardEarned) {
        _logger.info('User earned reward, continuing with export');
        // Save the date when ad was watched
        await prefs.setString('last_ad_watch_date', today);
      } else {
        _logger.info('User did not earn reward, cancelling export');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Please watch the ad completely to continue with export'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
    } else if (shouldShowAds &&
        !adService.isRewardedAdReady() &&
        !adAlreadyWatchedToday) {
      // Load an ad for next time if ads should be shown
      adService.loadRewardedAd();
      // If no ad is available but user hasn't watched one today, let them proceed this time
      _logger.info('No ad available but proceeding with export');
    } else {
      if (shouldShowAds) {
        _logger.info('User already watched ad today, proceeding with export');
        // Load an ad for next time
        adService.loadRewardedAd();
      } else {
        _logger.info(
            'Ads not required yet (less than 3 months since installation), proceeding with export');
      }
    }

    setState(() {
      _isExporting = true;
    });

    try {
      _logger.info('Starting Google Sheets export...');
      _logger.info('Getting mosque name from preferences...');

      final mosqueName = prefs.getString('masjid_name');

      if (mosqueName == null || mosqueName.isEmpty) {
        throw Exception(
            'Mosque name not found. Please set up the mosque name first.');
      }

      _logger.info('Mosque name: $mosqueName');

      final securityKey = prefs.getString('security_key_$mosqueName');
      if (securityKey == null || securityKey.isEmpty) {
        throw Exception('Security key not found for mosque: $mosqueName');
      }

      // Check what type of service we should use (direct or script-based)
      final usingDirectSheets = prefs.getBool('using_direct_sheets') ?? false;
      _logger.info('Using direct Google Sheets service: $usingDirectSheets');

      String? existingSpreadsheetId =
          prefs.getString('mosque_sheet_$mosqueName');

      // Log what we found in prefs
      if (existingSpreadsheetId != null && existingSpreadsheetId.isNotEmpty) {
        _logger.info('Found existing spreadsheet ID: $existingSpreadsheetId');
      } else {
        _logger
            .info('No existing spreadsheet ID found for mosque: $mosqueName');

        // Check if spreadsheetId is empty and this may be due to using offline backup
        _logger.info(
            'No spreadsheet ID found. User might have used offline backup. Prompting for ID...');

        // Ask the user to enter the spreadsheet ID
        existingSpreadsheetId = await _promptForSpreadsheetId(context);

        if (existingSpreadsheetId == null || existingSpreadsheetId.isEmpty) {
          _logger
              .info('User cancelled spreadsheet ID entry or provided empty ID');
          if (!mounted) return;

          setState(() {
            _isExporting = false;
          });

          // Show a choice dialog to either enter ID or create new spreadsheet
          final choice = await showDialog<String>(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: const Text('Spreadsheet Required'),
              content: const Text(
                'To export data, you need a valid spreadsheet ID. You can either enter an existing ID or create a new spreadsheet.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, 'cancel'),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, 'try_again'),
                  child: const Text('Enter ID'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, 'create_new'),
                  child: const Text('Create New'),
                ),
              ],
            ),
          );

          if (choice == 'try_again') {
            // Try again
            await _exportToGoogleSheets();
            return;
          } else if (choice == 'create_new') {
            // Continue with creating a new spreadsheet
          } else {
            // User cancelled
            return;
          }
        } else {
          // User provided an ID, save it for future use
          await prefs.setString(
              'mosque_sheet_$mosqueName', existingSpreadsheetId);
          await prefs.setString('mosque_code', existingSpreadsheetId);
          _logger.info(
              'Saved user-provided spreadsheet ID: $existingSpreadsheetId');
        }
      }

      // Check if the user has provided a spreadsheet ID in settings
      final userProvidedSpreadsheetId = prefs.getString('mosque_code');
      if (userProvidedSpreadsheetId != null &&
          userProvidedSpreadsheetId.isNotEmpty) {
        if (existingSpreadsheetId != userProvidedSpreadsheetId) {
          existingSpreadsheetId = userProvidedSpreadsheetId;
          _logger.info(
              'Saved user-provided spreadsheet ID: $existingSpreadsheetId');
        }
      }

      // Get or create spreadsheet ID using the appropriate service
      String spreadsheetId = existingSpreadsheetId ?? '';

      if (usingDirectSheets) {
        // Use the direct service approach
        _logger.info('Using direct Google Sheets service');

        // Check service account path
        final serviceAccountPath = prefs.getString('service_account_path');
        _logger.info(
            'Service account path found: ${serviceAccountPath != null && serviceAccountPath.isNotEmpty}');
        if (serviceAccountPath == null || serviceAccountPath.isEmpty) {
          throw Exception(
              'Service account file path not found. Please complete the advanced setup again.');
        }

        // Check API key
        final apiKey = prefs.getString('google_api_key');
        _logger.info('API key found: ${apiKey != null && apiKey.isNotEmpty}');
        if (apiKey == null || apiKey.isEmpty) {
          throw Exception(
              'Google API key not found. Please complete the advanced setup again with a valid API key.');
        }

        // Check if API key looks valid (basic check)
        if (!apiKey.startsWith('AIza')) {
          _logger.warning(
              'API key does not start with "AIza", might not be valid: ${apiKey.substring(0, min(10, apiKey.length))}...');
        }

        // Create direct service instance
        _logger.info('Initializing direct Google Sheets service...');
        final directService = DirectGoogleSheetsService();
        await directService.initialize(serviceAccountPath, apiKey);
        _logger.info('DirectGoogleSheetsService initialized successfully');

        if (spreadsheetId.isEmpty) {
          // Create a new spreadsheet using direct service
          final email = prefs.getString('sheets_user_email') ?? '';
          _logger.info(
              'Email for sharing: ${email.isNotEmpty ? email : "Not found"}');
          if (email.isEmpty) {
            throw Exception(
                'No email address found for sharing. Please complete the advanced setup again.');
          }

          _logger.info(
              'Creating new spreadsheet for: $mosqueName using direct service');
          spreadsheetId =
              await directService.createNewSpreadsheet(mosqueName, [email]);
          await prefs.setString('mosque_sheet_$mosqueName', spreadsheetId);
          await prefs.setString('mosque_code', spreadsheetId);
          _logger.info('New spreadsheet created with ID: $spreadsheetId');
        } else {
          _logger.info('Using existing spreadsheet with ID: $spreadsheetId');
        }

        // Get summary data
        final totalIncomeAllTime =
            await DatabaseService.instance.getTotalIncomeAllTime();
        final totalSavings = await DatabaseService.instance.getTotalSavings();
        final now = DateTime.now();
        final currentYear = now.year;
        final currentMonth = now.month;

        final currentMonthSavings = await DatabaseService.instance
            .getCurrentMonthSavings(currentMonth, currentYear);
        final currentMonthIncome = await DatabaseService.instance
            .getCurrentMonthIncome(currentMonth, currentYear);
        final totalDeductions =
            await DatabaseService.instance.getTotalDeductions();
        final monthlyDeductions = await DatabaseService.instance
            .getCurrentMonthDeductions(currentMonth, currentYear);
        final previousMonth = currentMonth == 1 ? 12 : currentMonth - 1;
        final previousYear = currentMonth == 1 ? currentYear - 1 : currentYear;
        final previousMonthSavings = await DatabaseService.instance
            .getCurrentMonthSavings(previousMonth, previousYear);

        // Prepare summary data
        final summaryData = [
          [
            totalIncomeAllTime,
            totalSavings,
            currentMonthSavings,
            currentMonthIncome,
            totalDeductions,
            monthlyDeductions,
            previousMonthSavings,
          ]
        ];

        // Export Summary sheet using direct service
        _logger.info('Exporting summary data using direct service...');
        try {
          await directService.exportData(mosqueName, summaryData, 'Summary');
        } catch (e) {
          _logger.warning('Failed to export Summary: ${e.toString()}');
        }

        // Create recovery data using direct service
        _logger.info('Creating recovery data using direct service...');
        await directService.createRecoveryData(
            spreadsheetId, securityKey, DatabaseService.instance);
      } else {
        // Use ScriptBasedExportService as before
        _logger.info('Using script-based export service');
        final scriptService = ScriptBasedExportService();

        if (spreadsheetId.isEmpty) {
          // Create a new spreadsheet using script-based approach
          _logger.info('Creating new spreadsheet for: $mosqueName');
          spreadsheetId = await scriptService.createNewSpreadsheet(mosqueName);
          await prefs.setString('mosque_sheet_$mosqueName', spreadsheetId);
          await prefs.setString('mosque_code', spreadsheetId);
        } else {
          // Check if the spreadsheet needs to be recreated (e.g., sheets were deleted)
          _logger.info('Checking if spreadsheet needs to be regenerated...');
          try {
            // First try to recreate basic sheets in the spreadsheet if they were deleted
            _logger.info('Attempting to recreate basic sheets if needed...');
            await scriptService.ensureRequiredSheetsExist(spreadsheetId);
          } catch (e) {
            _logger.warning('Error ensuring sheets exist: ${e.toString()}');
            // If we encounter an error, we'll continue with the export process,
            // as it will attempt to create missing sheets as needed
          }
        }

        // Validate spreadsheet ID doesn't contain underscores
        if (spreadsheetId.contains('_')) {
          if (!mounted) return;

          // Instead of just showing a message, let's regenerate the spreadsheet
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Spreadsheet ID contains underscores. Regenerating a new spreadsheet...'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 2),
            ),
          );

          // Clear the existing spreadsheet ID and try again
          await prefs.remove('mosque_sheet_$mosqueName');

          // Call this method again to create a new spreadsheet
          await _exportToGoogleSheets();
          return;
        }

        // Save the spreadsheet ID if it's not already saved
        if (prefs.getString('mosque_sheet_$mosqueName') == null) {
          await prefs.setString('mosque_sheet_$mosqueName', spreadsheetId);
        }

        // Create recovery data using script service
        _logger.info('Creating recovery data using script service...');
        final recoveryService = ScriptBasedRecoveryService(
          databaseService: DatabaseService.instance,
          scriptService: scriptService,
        );
        await recoveryService.createRecoveryData(spreadsheetId, securityKey);

        // Get all transactions and payers
        final transactions =
            await DatabaseService.instance.getAllTransactions();
        final payers = await DatabaseService.instance.getAllPayers();

        // Create a map of payer IDs to names
        final payerNames = {for (var p in payers) p.id!: p.name};

        // Get current date info
        final now = DateTime.now();
        final currentYear = now.year;
        final currentMonth = now.month;
        final firstDayOfMonth = DateTime(now.year, now.month, 1);

        // Calculate previous month
        final previousMonth = currentMonth == 1 ? 12 : currentMonth - 1;
        final previousYear = currentMonth == 1 ? currentYear - 1 : currentYear;

        // Get summary data
        final totalIncomeAllTime =
            await DatabaseService.instance.getTotalIncomeAllTime();
        final totalSavings = await DatabaseService.instance.getTotalSavings();
        final currentMonthSavings = await DatabaseService.instance
            .getCurrentMonthSavings(currentMonth, currentYear);
        final currentMonthIncome = await DatabaseService.instance
            .getCurrentMonthIncome(currentMonth, currentYear);
        final totalDeductions =
            await DatabaseService.instance.getTotalDeductions();
        final monthlyDeductions = await DatabaseService.instance
            .getCurrentMonthDeductions(currentMonth, currentYear);
        final previousMonthSavings = await DatabaseService.instance
            .getCurrentMonthSavings(previousMonth, previousYear);

        // Prepare summary data
        final summaryData = [
          [
            totalIncomeAllTime,
            totalSavings,
            currentMonthSavings,
            currentMonthIncome,
            totalDeductions,
            monthlyDeductions,
            previousMonthSavings,
          ]
        ];

        // Export Summary sheet
        _logger.info('Exporting summary data...');
        try {
          await scriptService.createSheetIfNotExists(spreadsheetId, 'Summary');
          await scriptService.exportData(mosqueName, summaryData, 'Summary');
        } catch (e) {
          _logger.warning('Failed to export Summary: ${e.toString()}');
        }
      }

      if (!mounted) return;
      _logger.info('SuccessfullyExport completed Successfully');

      // Increment export count after successful export
      int dailyExportCount = prefs.getInt('daily_export_count') ?? 0;
      dailyExportCount++;
      await prefs.setInt('daily_export_count', dailyExportCount);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Data exported to Cloud Successfully! (${dailyExportCount}/5 exports today)'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e, stackTrace) {
      _logger.severe('Error exporting data to Google Sheets', e, stackTrace);

      if (mounted) {
        // Determine if this is a setup issue that requires going back to setup
        bool isSetupError = e.toString().contains('not found') ||
            e.toString().contains('advanced setup') ||
            e.toString().contains('API key');

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
            action: isSetupError
                ? SnackBarAction(
                    label: 'Setup',
                    onPressed: () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (context) => const FirstTimeSetupScreen(),
                        ),
                      );
                    },
                  )
                : null,
          ),
        );

        // If this is a setup error, automatically navigate to setup screen after a delay
        if (isSetupError) {
          Future.delayed(const Duration(seconds: 6), () {
            if (mounted) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (context) => const FirstTimeSetupScreen(),
                ),
              );
            }
          });
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
  }

  String _getTitle() {
    switch (_selectedIndex) {
      case 0:
        return 'Manage Accounts';
      case 1:
        return 'Summary';
      case 2:
        return 'Reports';
      case 3:
        return 'Settings';
      default:
        return 'Manager';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_getTitle()),
        actions: [
          // Show export button only on Accounts screen and when not exporting
          if (_selectedIndex == 0 && !_isExporting)
            IconButton(
              icon: const Icon(Icons.cloud_upload),
              onPressed: _exportToGoogleSheets,
              tooltip: 'Export to Sheets',
            ),
          // Show loading indicator while exporting
          if (_selectedIndex == 0 && _isExporting)
            const Padding(
              padding: EdgeInsets.all(6.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                ),
              ),
            ),
          // Show premium notification on Summary screen
          if (_selectedIndex == 1)
            Transform.translate(
              offset: const Offset(0, -2), // Move up by 2 pixels
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Ad block image instead of premium icon
                  IconButton(
                    icon: Image.asset(
                      'assets/images/ad-block.png',
                      width: 26,
                      height: 26,
                    ),
                    onPressed: () => _showPremiumDialog(context),
                    tooltip: 'Upgrade to Premium',
                  ),
                  // Notification dot positioned precisely at top-right corner of the icon
                  Positioned(
                    right: 12, // Adjusted to align with icon edge
                    top: 12, // Adjusted to align with icon edge
                    child: FadeTransition(
                      opacity: _opacityAnimation ??
                          const AlwaysStoppedAnimation(1.0),
                      child: Container(
                        width: 8, // Smaller dot
                        height: 8, // Smaller dot
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () => _handleLogout(context),
              tooltip: 'Logout',
            ),
        ],
      ),
      body: Center(
        child: _widgetOptions.elementAt(_selectedIndex),
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet),
            label: 'Accounts',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics),
            label: 'Summary',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.picture_as_pdf),
            label: 'Reports',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        onTap: _onItemTapped,
      ),
    );
  }

  // Premium dialog
  void _showPremiumDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Premium Icon
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.workspace_premium,
                    size: 40,
                    color: Colors.amber,
                  ),
                ),
                const SizedBox(height: 24),
                // Title
                const TranslatedText(
                  'premium_title',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                // Description
                const TranslatedText(
                  'premium_description',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                // Free period notice
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.yellow.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Ads appear only after 3 months of free usage',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.amber,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Feature list
                ..._buildPremiumFeatures(),
                const SizedBox(height: 24),
                // Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const TranslatedText('maybe_later'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const PremiumScreen(),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const TranslatedText('upgrade_now'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildPremiumFeatures() {
    final features = [
      {'icon': Icons.bar_chart, 'key': 'premium_feature_charts'},
      {'icon': Icons.picture_as_pdf, 'key': 'premium_feature_reports'},
      {'icon': Icons.cloud_done, 'key': 'premium_feature_backup'},
      {'icon': Icons.public_off, 'key': 'premium_feature_adfree'},
    ];

    return features.map((feature) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                feature['icon'] as IconData,
                color: Colors.green,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TranslatedText(
                feature['key'] as String,
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  // New method to prompt for spreadsheet ID
  Future<String?> _promptForSpreadsheetId(BuildContext context) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Enter Spreadsheet ID'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'No spreadsheet ID was found. This may happen if you skipped the "Enable Cloud Database" step during setup or used an offline backup.',
            ),
            const SizedBox(height: 8),
            const Text(
              'If you already have a Google Spreadsheet for this mosque, please enter its ID below. Otherwise, click Cancel and the system will create a new one for you.',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Spreadsheet ID',
                helperText: 'Find this in your Google Sheets URL',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }
}
