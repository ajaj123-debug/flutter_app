import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:logging/logging.dart';
import 'dart:async';
import 'installation_date_service.dart';

class AdService {
  static final AdService _instance = AdService._internal();
  static final _logger = Logger('AdService');

  factory AdService() {
    return _instance;
  }

  AdService._internal();

  // Rewarded ad properties
  bool _isRewardedAdLoading = false;
  RewardedAd? _rewardedAd;

  // Interstitial ad properties
  bool _isInterstitialAdLoading = false;
  InterstitialAd? _interstitialAd;

  // Banner ad properties
  BannerAd? _bannerAd;
  bool _isBannerAdLoaded = false;

  // Flag to track if three months have passed since installation
  bool _threeMonthsPassed = false;

  /// Initialize the Mobile Ads SDK
  Future<void> initialize() async {
    try {
      _logger.info('Initializing MobileAds');
      await MobileAds.instance.initialize();
      _logger.info('MobileAds initialized successfully');

      // Initialize installation date service
      final installationService = InstallationDateService();
      await installationService.initialize();

      // Check if 3 months have passed
      _threeMonthsPassed = await installationService.isThreeMonthsPassed();
      _logger.info('Three months passed check: $_threeMonthsPassed');
    } catch (e) {
      _logger.severe('Error initializing MobileAds: $e');
    }
  }

  // REWARDED ADS

  /// Load a rewarded ad
  Future<void> loadRewardedAd() async {
    if (_isRewardedAdLoading || _rewardedAd != null) {
      _logger.info('Rewarded ad is already loaded or loading');
      return;
    }

    // Check if ads should be shown based on installation date
    final installationService = InstallationDateService();
    _threeMonthsPassed = await installationService.isThreeMonthsPassed();

    if (!_threeMonthsPassed) {
      _logger.info(
          'Not loading ad as three months have not passed since installation');
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
    // If three months haven't passed, pretend ad was watched successfully
    if (!_threeMonthsPassed) {
      _logger.info(
          'Skipping ad as three months have not passed since installation');
      return true;
    }

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

  /// Check if a rewarded ad is ready to show
  bool isRewardedAdReady() {
    // If three months haven't passed, pretend ad is not available
    if (!_threeMonthsPassed) {
      return false;
    }
    return _rewardedAd != null;
  }

  // INTERSTITIAL ADS

  /// Load an interstitial ad
  Future<void> loadInterstitialAd() async {
    if (_isInterstitialAdLoading || _interstitialAd != null) {
      _logger.info('Interstitial ad is already loaded or loading');
      return;
    }

    // Check if ads should be shown based on installation date
    if (!_threeMonthsPassed) {
      _logger.info(
          'Not loading interstitial ad as three months have not passed since installation');
      return;
    }

    _isInterstitialAdLoading = true;

    try {
      _logger.info('Loading interstitial ad');
      await InterstitialAd.load(
        adUnitId: _getInterstitialAdUnitId(),
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (InterstitialAd ad) {
            _logger.info('Interstitial ad loaded successfully');
            _interstitialAd = ad;
            _isInterstitialAdLoading = false;
          },
          onAdFailedToLoad: (LoadAdError error) {
            _logger.warning('Interstitial ad failed to load: $error');
            _interstitialAd = null;
            _isInterstitialAdLoading = false;
          },
        ),
      );
    } catch (e) {
      _logger.severe('Error loading interstitial ad: $e');
      _interstitialAd = null;
      _isInterstitialAdLoading = false;
    }
  }

  /// Show the interstitial ad
  /// Returns true if the ad was shown successfully
  Future<bool> showInterstitialAd() async {
    // If three months haven't passed, skip showing ad
    if (!_threeMonthsPassed) {
      _logger.info(
          'Skipping interstitial ad as three months have not passed since installation');
      return true;
    }

    if (_interstitialAd == null) {
      _logger.warning('Attempted to show interstitial ad before it was loaded');
      // Try to load a new ad for next time
      loadInterstitialAd();
      return false;
    }

    final completer = Completer<bool>();

    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (InterstitialAd ad) {
        _logger.info('Interstitial ad dismissed');
        ad.dispose();
        _interstitialAd = null;
        loadInterstitialAd(); // Load the next ad
        completer.complete(true);
      },
      onAdFailedToShowFullScreenContent: (InterstitialAd ad, AdError error) {
        _logger.warning('Interstitial ad failed to show: $error');
        ad.dispose();
        _interstitialAd = null;
        loadInterstitialAd(); // Load the next ad
        completer.complete(false);
      },
      onAdShowedFullScreenContent: (InterstitialAd ad) {
        _logger.info('Interstitial ad showed fullscreen content');
      },
    );

    _interstitialAd!.setImmersiveMode(true);
    await _interstitialAd!.show();
    return completer.future;
  }

  /// Dispose of the interstitial ad if it exists
  void disposeInterstitialAd() {
    _interstitialAd?.dispose();
    _interstitialAd = null;
  }

  /// Check if an interstitial ad is ready to show
  bool isInterstitialAdReady() {
    // If three months haven't passed, pretend ad is not available
    if (!_threeMonthsPassed) {
      return false;
    }
    return _interstitialAd != null;
  }

  // BANNER ADS

  /// Load a banner ad
  Future<void> loadBannerAd(AdSize size) async {
    // Check if ads should be shown based on installation date
    if (!_threeMonthsPassed) {
      _logger.info(
          'Not loading banner ad as three months have not passed since installation');
      return;
    }

    // Dispose existing banner ad if any
    disposeBannerAd();

    try {
      _logger.info('Loading banner ad');
      _bannerAd = BannerAd(
        adUnitId: _getBannerAdUnitId(),
        size: size,
        request: const AdRequest(),
        listener: BannerAdListener(
          onAdLoaded: (Ad ad) {
            _logger.info('Banner ad loaded successfully');
            _isBannerAdLoaded = true;
          },
          onAdFailedToLoad: (Ad ad, LoadAdError error) {
            _logger.warning('Banner ad failed to load: $error');
            ad.dispose();
            _isBannerAdLoaded = false;
          },
          onAdClosed: (Ad ad) {
            _logger.info('Banner ad closed');
          },
        ),
      );

      await _bannerAd!.load();
    } catch (e) {
      _logger.severe('Error loading banner ad: $e');
      _isBannerAdLoaded = false;
    }
  }

  /// Get the banner ad widget if loaded
  Widget? getBannerAdWidget() {
    // If three months haven't passed, return null
    if (!_threeMonthsPassed) {
      return null;
    }

    if (_bannerAd != null && _isBannerAdLoaded) {
      return SizedBox(
        width: _bannerAd!.size.width.toDouble(),
        height: _bannerAd!.size.height.toDouble(),
        child: AdWidget(ad: _bannerAd!),
      );
    }
    return null;
  }

  /// Dispose of the banner ad if it exists
  void disposeBannerAd() {
    _bannerAd?.dispose();
    _bannerAd = null;
    _isBannerAdLoaded = false;
  }

  /// Check if a banner ad is ready to show
  bool isBannerAdReady() {
    // If three months haven't passed, pretend ad is not available
    if (!_threeMonthsPassed) {
      return false;
    }
    return _bannerAd != null && _isBannerAdLoaded;
  }

  // AD UNIT IDs

  /// Get the appropriate rewarded ad unit ID
  String _getRewardedAdUnitId() {
    // Use production ad ID as we're going to production
    return 'ca-app-pub-8830952142771120/9101316582'; // Production rewarded ad ID
  }

  /// Get the appropriate interstitial ad unit ID
  String _getInterstitialAdUnitId() {
    // Use test ad unit IDs for development
    return 'ca-app-pub-3940256099942544/1033173712'; // Test interstitial ad unit ID
    // In production, return your actual interstitial ad unit ID
    // return 'your-actual-interstitial-ad-unit-id';
  }

  /// Get the appropriate banner ad unit ID
  String _getBannerAdUnitId() {
    // Use test ad unit IDs for development
    return 'ca-app-pub-3940256099942544/6300978111'; // Test banner ad unit ID
    // In production, return your actual banner ad unit ID
    // return 'your-actual-banner-ad-unit-id';
  }

  /// Check if we should show ads based on installation date
  Future<bool> shouldShowAds() async {
    final installationService = InstallationDateService();
    _threeMonthsPassed = await installationService.isThreeMonthsPassed();
    return _threeMonthsPassed;
  }
}
