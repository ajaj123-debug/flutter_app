import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../widgets/prayer_card.dart';

/// A utility class for managing image caching throughout the app
class ImageCacheManager {
  /// Private constructor to prevent instantiation
  ImageCacheManager._();
  
  /// Map of all important images that should be preloaded
  static final Map<String, String> _importantImages = {
    'prayer_background': PrayerCard.backgroundImageUrl,
    // Add more images here as needed
  };
  
  /// Preloads all important images into the cache
  static void preloadImages(BuildContext context) {
    for (final entry in _importantImages.entries) {
      precacheImage(
        CachedNetworkImageProvider(
          entry.value,
          cacheKey: entry.key,
        ),
        context,
      );
    }
  }
  
  /// Clears the image cache (useful for debugging or when user logs out)
  static void clearCache() {
    imageCache.clear();
    imageCache.clearLiveImages();
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  }
  
  /// Gets a CachedNetworkImageProvider for the given image key
  static CachedNetworkImageProvider getImageProvider(String imageKey) {
    final url = _importantImages[imageKey];
    if (url == null) {
      throw ArgumentError('Image key "$imageKey" not found in important images');
    }
    
    return CachedNetworkImageProvider(
      url,
      cacheKey: imageKey,
    );
  }
} 