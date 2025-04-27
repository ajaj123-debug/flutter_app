import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:logging/logging.dart';
import 'dart:async';

class AdService {
  static final AdService _instance = AdService._internal();
  static final _logger = Logger('AdService');

  factory AdService() {
    return _instance;
  }

  AdService._internal();

  // This flag is used to prevent multiple ad loads
  bool _isRewardedAdLoading = false;
  RewardedAd? _rewardedAd;

  /// Initialize the Mobile Ads SDK
  Future<void> initialize() async {
    try {
      _logger.info('Initializing MobileAds');
      await MobileAds.instance.initialize();
      _logger.info('MobileAds initialized successfully');
    } catch (e) {
      _logger.severe('Error initializing MobileAds: $e');
    }
  }

  /// Load a rewarded ad
  Future<void> loadRewardedAd() async {
    if (_isRewardedAdLoading || _rewardedAd != null) {
      _logger.info('Rewarded ad is already loaded or loading');
      return;
    }

    _isRewardedAdLoading = true;

    try {
      _logger.info('Loading rewarded ad');
      await RewardedAd.load(
        adUnitId: _getRewardedAdUnitId(),
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (RewardedAd ad) {
            _logger.info('Rewarded ad loaded successfully');
            _rewardedAd = ad;
            _isRewardedAdLoading = false;
          },
          onAdFailedToLoad: (LoadAdError error) {
            _logger.warning('Rewarded ad failed to load: $error');
            _rewardedAd = null;
            _isRewardedAdLoading = false;
          },
        ),
      );
    } catch (e) {
      _logger.severe('Error loading rewarded ad: $e');
      _rewardedAd = null;
      _isRewardedAdLoading = false;
    }
  }

  /// Show the rewarded ad
  /// Returns true if the user received the reward
  Future<bool> showRewardedAd(BuildContext context) async {
    if (_rewardedAd == null) {
      _logger.warning('Attempted to show rewarded ad before it was loaded');

      // Show a dialog to the user
      if (context.mounted) {
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Ad Not Ready'),
            content: const Text('Please try again later.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }

      // Try to load a new ad for next time
      loadRewardedAd();
      return false;
    }

    final completer = Completer<bool>();

    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (RewardedAd ad) {
        _logger.info('Ad dismissed');
        ad.dispose();
        _rewardedAd = null;
        loadRewardedAd(); // Load the next ad
        // If the completer hasn't completed yet, complete with false
        if (!completer.isCompleted) {
          completer.complete(false);
        }
      },
      onAdFailedToShowFullScreenContent: (RewardedAd ad, AdError error) {
        _logger.warning('Ad failed to show: $error');
        ad.dispose();
        _rewardedAd = null;
        loadRewardedAd(); // Load the next ad
        completer.complete(false);
      },
      onAdShowedFullScreenContent: (RewardedAd ad) {
        _logger.info('Ad showed fullscreen content');
      },
    );

    _rewardedAd!.setImmersiveMode(true);

    // Show the ad and handle reward
    _rewardedAd!.show(
      onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
        _logger.info('User earned reward: ${reward.amount} ${reward.type}');
        completer.complete(true);
      },
    );

    return completer.future;
  }

  /// Dispose of the rewarded ad if it exists
  void disposeRewardedAd() {
    _rewardedAd?.dispose();
    _rewardedAd = null;
  }

  /// Get the appropriate ad unit ID
  String _getRewardedAdUnitId() {
    // Use test ad unit IDs for development
    return 'ca-app-pub-3940256099942544/5224354917'; // Test ad unit ID
  }

  /// Check if a rewarded ad is ready to show
  bool isRewardedAdReady() {
    return _rewardedAd != null;
  }
}
