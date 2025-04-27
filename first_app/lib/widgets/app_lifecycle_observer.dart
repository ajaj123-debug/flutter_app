import 'package:flutter/widgets.dart';
import '../services/app_session_service.dart';

class AppLifecycleObserver extends WidgetsBindingObserver {
  final AppSessionService _sessionService = AppSessionService();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _sessionService.startSession();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _sessionService.endSession();
        break;
      default:
        break;
    }
  }
} 