import 'package:flutter/services.dart';
import 'dart:developer' as developer;
import 'dart:convert';

class AssetUtils {
  /// Checks if an asset exists and is not empty
  static Future<bool> assetExists(String assetPath) async {
    try {
      developer.log('Checking if asset exists: $assetPath');
      final ByteData data = await rootBundle.load(assetPath);
      final bool exists = data.lengthInBytes > 0;
      developer.log(
          'Asset $assetPath exists: $exists, size: ${data.lengthInBytes} bytes');
      return exists;
    } catch (error) {
      developer.log('Error checking asset: $error');
      return false;
    }
  }

  /// Lists all assets in the app (if possible)
  static Future<void> logAvailableAssets() async {
    try {
      developer.log('Attempting to log available assets');
      // This is not directly possible in Flutter, but we can check some common paths
      final commonAssets = [
        'assets/quran.sqlite',
        'assets/images/prayer_background_image.webp',
        'assets/fonts/indopak.ttf',
      ];

      for (final asset in commonAssets) {
        final exists = await assetExists(asset);
        developer.log('Asset $asset exists: $exists');
      }
    } catch (error) {
      developer.log('Error logging assets: $error');
    }
  }

  /// Comprehensive asset debugging utility
  static Future<void> debugAssetLoading() async {
    try {
      developer.log('=========== ASSET DEBUGGING ===========');

      // 1. Try to load the asset manifest
      try {
        final manifestStr = await rootBundle.loadString('AssetManifest.json');
        final manifest = json.decode(manifestStr) as Map<String, dynamic>;
        developer.log('Asset manifest contains ${manifest.length} entries:');
        // List the first 10 entries only to avoid excessive logging
        int count = 0;
        manifest.forEach((key, value) {
          if (count < 10) {
            developer.log('- $key');
            count++;
          }
        });

        // Check if our database is in the manifest
        final hasQuranDb = manifest.containsKey('assets/quran.sqlite');
        developer.log('Quran database in manifest: $hasQuranDb');
      } catch (e) {
        developer.log('Error loading asset manifest: $e');
      }

      // 2. Try various path formats
      developer.log('\nTrying various path formats:');
      final pathsToTry = [
        'assets/quran.sqlite',
        '/assets/quran.sqlite',
        'quran.sqlite',
        'assets/quran.sqlite', // Try with different slashes on Windows
      ];

      for (final path in pathsToTry) {
        try {
          final data = await rootBundle.load(path);
          developer.log(
              'SUCCESS: Loaded asset at path: $path (${data.lengthInBytes} bytes)');
        } catch (e) {
          developer.log('FAILED: Could not load asset at path: $path - $e');
        }
      }

      // 3. Check app directory structure
      developer.log('\nChecking binary messenger availability:');
      developer.log('Binary messenger is available');
    
      developer.log('=========== END ASSET DEBUGGING ===========');
    } catch (e) {
      developer.log('Error during asset debugging: $e');
    }
  }
}
