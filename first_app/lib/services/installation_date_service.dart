import 'package:shared_preferences/shared_preferences.dart';
import 'package:logging/logging.dart';

/// Service to track installation date and determine if ads should be shown
/// based on time since installation
class InstallationDateService {
  static final InstallationDateService _instance =
      InstallationDateService._internal();
  static final _logger = Logger('InstallationDateService');

  // Key for storing installation date in SharedPreferences
  static const String _installationDateKey = 'installation_date';

  // Premium status key
  static const String _isPremiumKey = 'is_premium';

  factory InstallationDateService() {
    return _instance;
  }

  InstallationDateService._internal();

  /// Initialize the service, storing installation date if it doesn't exist
  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Check if installation date is already stored
      if (!prefs.containsKey(_installationDateKey)) {
        // Store current date as installation date
        final now = DateTime.now();
        await prefs.setString(_installationDateKey, now.toIso8601String());
        _logger.info('Installation date set: ${now.toIso8601String()}');
      } else {
        _logger.info(
            'Installation date already exists: ${prefs.getString(_installationDateKey)}');
      }
    } catch (e) {
      _logger.severe('Error initializing InstallationDateService: $e');
    }
  }

  /// Get the installation date
  Future<DateTime?> getInstallationDate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dateString = prefs.getString(_installationDateKey);

      if (dateString != null) {
        return DateTime.parse(dateString);
      }
      return null;
    } catch (e) {
      _logger.severe('Error getting installation date: $e');
      return null;
    }
  }

  /// Check if it's been 1 year since installation
  Future<bool> isThreeMonthsPassed() async {
    try {
      // If user is premium, always return false (don't show ads)
      if (await isPremium()) {
        return false;
      }

      final installDate = await getInstallationDate();

      if (installDate == null) {
        // If installation date not found, initialize and return false
        await initialize();
        return false;
      }

      final now = DateTime.now();
      final oneYearLater =
          DateTime(installDate.year + 1, installDate.month, installDate.day);

      final isPassed = now.isAfter(oneYearLater);
      _logger.info(
          'One year passed: $isPassed (Install: $installDate, Threshold: $oneYearLater)');

      return isPassed;
    } catch (e) {
      _logger.severe('Error checking if one year passed: $e');
      return false;
    }
  }

  /// Check if user has premium status
  Future<bool> isPremium() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_isPremiumKey) ?? false;
    } catch (e) {
      _logger.severe('Error checking premium status: $e');
      return false;
    }
  }

  /// Set premium status
  Future<void> setPremium(bool isPremium) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_isPremiumKey, isPremium);
      _logger.info('Premium status set to: $isPremium');
    } catch (e) {
      _logger.severe('Error setting premium status: $e');
    }
  }

  /// FOR TESTING ONLY: Force one year to have passed by setting installation date to 1 year ago
  Future<void> forceThreeMonthsPassedForTesting() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      final oneYearAgo = DateTime(now.year - 1, now.month, now.day);
      await prefs.setString(_installationDateKey, oneYearAgo.toIso8601String());
      _logger.warning(
          'TESTING: Installation date artificially set to 1 year ago: ${oneYearAgo.toIso8601String()}');
    } catch (e) {
      _logger.severe('Error forcing one year passed: $e');
    }
  }
}
