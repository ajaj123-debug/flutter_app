import 'dart:async';
import 'user_database_service.dart';
import '../utils/logger.dart';

class AppSessionService {
  static Timer? _sessionTimer;
  static DateTime? _sessionStartTime;
  static final AppSessionService _instance = AppSessionService._internal();

  factory AppSessionService() => _instance;

  AppSessionService._internal();

  void startSession() {
    _sessionStartTime = DateTime.now();
    _sessionTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _updatePoints();
    });
  }

  Future<void> endSession() async {
    _sessionTimer?.cancel();
    _sessionTimer = null;
    await _updatePoints();
    _sessionStartTime = null;
  }

  Future<void> _updatePoints() async {
    if (_sessionStartTime == null) return;

    final duration = DateTime.now().difference(_sessionStartTime!);
    // Calculate points: 100 points per 10 seconds
    final points = (duration.inSeconds / 10).floor() * 100;

    final currentPoints = await UserDatabaseService().getTotalPoints();
    final newPoints = currentPoints + points;

    // Update local database
    try {
      await UserDatabaseService().setTotalPoints(newPoints);
      Logger.info('Points updated: $newPoints');
    } catch (e) {
      Logger.error('Failed to update points', e);
    }
  }
}
