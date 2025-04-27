import 'dart:async';
import 'package:flutter/material.dart';
import '../models/leaderboard_models.dart';
import 'leaderboard_service.dart';
import 'user_database_service.dart';
import '../utils/logger.dart';

class AppSessionService {
  static Timer? _sessionTimer;
  static DateTime? _sessionStartTime;
  static final AppSessionService _instance = AppSessionService._internal();

  factory AppSessionService() => _instance;

  AppSessionService._internal();

  final LeaderboardService _leaderboardService = LeaderboardService();

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

    final userId = await UserDatabaseService().getUserId();
    final username = await UserDatabaseService().getUsername();
    final currentPoints = await UserDatabaseService().getTotalPoints();
    final newPoints = currentPoints + points;

    // Update local database first
    await UserDatabaseService().setTotalPoints(newPoints);

    final user = LeaderboardUser(
      id: userId,
      name: username,
      points: newPoints,
      lastUpdated: DateTime.now(),
      rank: 0, // Will be updated when leaderboard is fetched
    );

    // Sync with Google Sheets
    try {
      await _leaderboardService.updateUserPoints(user);
    } catch (e) {
      Logger.error('Failed to sync with Google Sheets', e);
    }
  }
}
