import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/home_screen.dart';
import 'screens/role_selection_screen.dart';
import 'screens/manager_main_screen.dart';
import 'screens/first_time_setup_screen.dart';
import 'screens/quran_screen.dart';
import 'screens/quran_continuous_screen.dart';
import 'screens/prayer_timings_screen.dart';
import 'utils/image_cache_manager.dart';
import 'services/user_database_service.dart';
import 'package:logging/logging.dart';
import 'services/language_service.dart';
import 'services/ad_service.dart';
import 'services/installation_date_service.dart';
import 'dart:async'; // Add import for StreamSubscription
import 'utils/asset_utils.dart'; // Add import for AssetUtils

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set status bar to be transparent
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));

  // Initialize logging
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    if (record.error != null) {
      print('Error: ${record.error}');
      print('Stack trace: ${record.stackTrace}');
    }
  });

  final appLogger = Logger('App');
  appLogger.info('App starting up...');

  // Check if important assets exist
  try {
    appLogger.info('Checking important assets...');
    final quranAssetExists =
        await AssetUtils.assetExists('assets/quran.sqlite');
    appLogger.info('Quran asset exists: $quranAssetExists');

    // Log all available assets
    await AssetUtils.logAvailableAssets();
  } catch (e, stackTrace) {
    appLogger.severe('Error checking assets', e, stackTrace);
  }

  // Initialize installation date service
  try {
    appLogger.info('Initializing InstallationDateService...');
    await InstallationDateService().initialize();
    final installDate = await InstallationDateService().getInstallationDate();
    appLogger.info('Installation date: $installDate');
    final threeMonthsPassed =
        await InstallationDateService().isThreeMonthsPassed();
    appLogger.info('Three months passed: $threeMonthsPassed');
  } catch (e, stackTrace) {
    appLogger.severe(
        'Failed to initialize InstallationDateService', e, stackTrace);
  }

  // Initialize language service
  try {
    appLogger.info('Initializing language service...');
    await LanguageService.instance.initialize();
    appLogger.info(
        'Language service initialized with language: ${LanguageService.instance.currentLanguage}');

    // Log some test translations
    final testKeys = ['dashboard', 'settings', 'total_income'];
    for (final key in testKeys) {
      appLogger.info(
          'Test translation for "$key": "${LanguageService.instance.translate(key)}"');
    }
  } catch (e, stackTrace) {
    appLogger.severe('Failed to initialize language service', e, stackTrace);
  }

  // Initialize AdService
  try {
    appLogger.info('Initializing AdService...');
    await AdService().initialize();
    appLogger.info('AdService initialized successfully');
    // Preload a rewarded ad
    AdService().loadRewardedAd();
  } catch (e, stackTrace) {
    appLogger.severe('Failed to initialize AdService', e, stackTrace);
  }

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  final _logger = Logger('MyApp');
  bool _isFirstLaunch = true;
  String? _userRole;
  bool _isManagerSetupComplete = false;
  String _currentLanguage = 'en';
  // Add a subscription for the language change stream
  StreamSubscription<String>? _languageChangeSubscription;
  // Add a key that will change when language changes to force complete app rebuild
  Key _appKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeApp();

    // Load current language and listen for changes
    _currentLanguage = LanguageService.instance.currentLanguage;
    _logger.info('App initialized with language: $_currentLanguage');

    // Subscribe to language changes
    _languageChangeSubscription =
        LanguageService.instance.onLanguageChanged.listen((newLanguage) {
      _logger.info('Language change notification received: $newLanguage');
      setState(() {
        _currentLanguage = newLanguage;
        // Remove the key change to prevent app reset
        // _appKey = UniqueKey();
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Check for language changes when dependencies change
    final newLanguage = LanguageService.instance.currentLanguage;
    if (newLanguage != _currentLanguage) {
      _logger.info('Language changed from $_currentLanguage to $newLanguage');
      _currentLanguage = newLanguage;
      setState(() {
        // Remove the key change to prevent app reset
        // _appKey = UniqueKey();
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _languageChangeSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // App came to foreground
      _updatePrayerTimes();

      // Check ad status when app resumes
      _checkAdStatus();

      // Check for language changes when app resumes
      final newLanguage = LanguageService.instance.currentLanguage;
      if (newLanguage != _currentLanguage) {
        _logger.info(
            'Language changed after resume from $_currentLanguage to $newLanguage');
        _currentLanguage = newLanguage;
        setState(() {
          // Create a new key to force complete app rebuild
          _appKey = UniqueKey();
        });
      }
    }
  }

  Future<void> _initializeApp() async {
    try {
      print('🔄 Initializing app...');
      final prefs = await SharedPreferences.getInstance();

      // Check if it's first launch
      _isFirstLaunch = prefs.getBool('first_launch') ?? true;
      _userRole = prefs.getString('user_role');

      // Check if manager setup is complete by checking for mosque name
      final mosqueName = prefs.getString('masjid_name');
      _isManagerSetupComplete =
          _userRole == 'manager' && mosqueName != null && mosqueName.isNotEmpty;

      // If manager role but no setup, force first launch
      if (_userRole == 'manager' && !_isManagerSetupComplete) {
        _isFirstLaunch = true;
        await prefs.setBool('first_launch', true);
      }

      final userDatabaseService = UserDatabaseService();

      // Get user ID and ensure initial data is sent
      final userId = await userDatabaseService.getUserId();
      print('👤 User ID: $userId');

      // Set up app state change listener
      WidgetsBinding.instance.addObserver(
        AppLifecycleObserver(userDatabaseService),
      );

      // Check ad status during initialization
      _checkAdStatus();

      setState(() {}); // Update UI with loaded preferences
      print('Successfully App initialization complete');
    } catch (e) {
      print('❌ Error initializing app: $e');
      print('Stack trace: ${StackTrace.current}');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Prefetch the prayer background image once the app has a context
    _prefetchImages(context);

    return MaterialApp(
      key: _appKey, // Add key here to force rebuild when language changes
      title: 'MosqueEase',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.teal,
        fontFamily: 'Roboto',
        appBarTheme: const AppBarTheme(
          systemOverlayStyle: SystemUiOverlayStyle.dark,
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
      ),
      home: _isFirstLaunch
          ? const RoleSelectionScreen()
          : _userRole == 'manager' && !_isManagerSetupComplete
              ? const FirstTimeSetupScreen()
              : _userRole == 'manager'
                  ? const ManagerMainScreen()
                  : const HomeScreen(),
      routes: {
        '/quran': (context) => const QuranScreen(),
        '/quran_continuous': (context) => const QuranContinuousScreen(),
        '/prayer_timings': (context) => const PrayerTimingsScreen(),
      },
    );
  }

  void _prefetchImages(BuildContext context) {
    // Use our ImageCacheManager to preload all important images
    ImageCacheManager.preloadImages(context);
  }

  void _updatePrayerTimes() {
    // Implementation of _updatePrayerTimes method
  }

  // Check if ads should be shown based on installation date
  Future<void> _checkAdStatus() async {
    try {
      final shouldShowAds = await AdService().shouldShowAds();
      _logger
          .info('Should show ads based on installation date: $shouldShowAds');

      if (shouldShowAds) {
        // If ads should be shown, preload one
        AdService().loadRewardedAd();
      }
    } catch (e) {
      _logger.severe('Error checking ad status: $e');
    }
  }
}

class AppLifecycleObserver extends WidgetsBindingObserver {
  final UserDatabaseService _userDatabaseService;

  AppLifecycleObserver(this._userDatabaseService);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        print('📱 App resumed');
        break;
      case AppLifecycleState.paused:
        print('📱 App paused');
        break;
      default:
        break;
    }
  }
}
