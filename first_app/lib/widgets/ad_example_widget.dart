import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../services/ad_service.dart';

class AdExampleWidget extends StatefulWidget {
  const AdExampleWidget({Key? key}) : super(key: key);

  @override
  State<AdExampleWidget> createState() => _AdExampleWidgetState();
}

class _AdExampleWidgetState extends State<AdExampleWidget> {
  final AdService _adService = AdService();
  bool _isRewardedAdReady = false;
  bool _isInterstitialAdReady = false;
  Widget? _bannerAdWidget;

  @override
  void initState() {
    super.initState();
    _loadAds();
  }

  @override
  void dispose() {
    _adService.disposeRewardedAd();
    _adService.disposeInterstitialAd();
    _adService.disposeBannerAd();
    super.dispose();
  }

  Future<void> _loadAds() async {
    // Check if we should show ads
    final shouldShowAds = await _adService.shouldShowAds();
    if (!shouldShowAds) {
      return;
    }

    // Load rewarded ad
    await _adService.loadRewardedAd();

    // Load interstitial ad
    await _adService.loadInterstitialAd();

    // Load banner ad
    await _adService.loadBannerAd(AdSize.banner);

    // Update state to reflect ad readiness
    if (mounted) {
      setState(() {
        _isRewardedAdReady = _adService.isRewardedAdReady();
        _isInterstitialAdReady = _adService.isInterstitialAdReady();
        _bannerAdWidget = _adService.getBannerAdWidget();
      });
    }
  }

  Future<void> _showRewardedAd() async {
    final result = await _adService.showRewardedAd(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            'Rewarded ad result: ${result ? 'Reward earned' : 'No reward'}'),
      ),
    );

    // Update state to reflect new ad readiness
    if (mounted) {
      setState(() {
        _isRewardedAdReady = _adService.isRewardedAdReady();
      });
    }
  }

  Future<void> _showInterstitialAd() async {
    final result = await _adService.showInterstitialAd();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            'Interstitial ad result: ${result ? 'Shown' : 'Failed to show'}'),
      ),
    );

    // Update state to reflect new ad readiness
    if (mounted) {
      setState(() {
        _isInterstitialAdReady = _adService.isInterstitialAdReady();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'AdMob Examples',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),

        // Banner Ad
        if (_bannerAdWidget != null) ...[
          const Text('Banner Ad:'),
          const SizedBox(height: 8),
          Center(child: _bannerAdWidget!),
          const SizedBox(height: 16),
        ],

        // Interstitial Ad
        ElevatedButton(
          onPressed: _isInterstitialAdReady ? _showInterstitialAd : null,
          child: Text(_isInterstitialAdReady
              ? 'Show Interstitial Ad'
              : 'Interstitial Ad Not Ready'),
        ),
        const SizedBox(height: 16),

        // Rewarded Ad
        ElevatedButton(
          onPressed: _isRewardedAdReady ? _showRewardedAd : null,
          child: Text(_isRewardedAdReady
              ? 'Show Rewarded Ad'
              : 'Rewarded Ad Not Ready'),
        ),

        const SizedBox(height: 16),
        TextButton(
          onPressed: _loadAds,
          child: const Text('Reload Ads'),
        ),
      ],
    );
  }
}
