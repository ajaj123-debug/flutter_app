# Troubleshooting Guide

## Quran Database Loading Issues

If you encounter the error **"Error loading Quran data: unable to load assets: assets/quran.sqlite. The assets does not exist or has empty data"**, follow these steps to resolve the issue:

### Verify Asset File

1. Make sure the `quran.sqlite` file exists in the assets folder:
   - Check the file path: `first_app/assets/quran.sqlite`
   - Verify the file is not corrupted by checking its size (should be around 2.7MB)

### Update pubspec.yaml

1. Make sure the `quran.sqlite` file is correctly listed in your pubspec.yaml:
   ```yaml
   assets:
     - assets/images/
     - assets/fonts/
     - assets/quran.sqlite
   ```
2. Run `flutter pub get` after updating the pubspec.yaml file.

### Clean and Rebuild

1. Run the following commands in the project root directory:
   ```
   flutter clean
   flutter pub get
   ```

### Manually Create Assets Folder

If the issue persists, try manually creating the assets folder structure in the build:

1. For Android:
   - Navigate to `android/app/src/main/assets`
   - Create this directory if it doesn't exist
   - Copy the `quran.sqlite` file directly to this location

2. For iOS:
   - Navigate to `ios/Runner/Assets`
   - Create this directory if it doesn't exist
   - Copy the `quran.sqlite` file directly to this location

### Alternative Approach

If the database still fails to load from assets, you can try an alternative approach:

1. Include the database as a local file in your app's documents directory:
   ```dart
   // In your QuranDatabaseService class
   Future<void> ensureDatabaseExists() async {
     final dbPath = await getDatabasesPath();
     final path = join(dbPath, "quran.db");
     
     if (!await databaseExists(path)) {
       // If the database doesn't exist, you can:
       // Option 1: Download it from a server
       // Option 2: Bundle it with the app using another method
     }
   }
   ```

2. Consider using Firebase Storage or another cloud storage to host the database file and download it on first run.

### Diagnostics

Add these diagnostic steps to your code:

```dart
Future<void> debugAssetLoading() async {
  try {
    final manifest = await rootBundle.loadString('AssetManifest.json');
    print('Asset manifest: $manifest');
    
    // Try loading with various path formats
    final paths = [
      'assets/quran.sqlite',
      '/assets/quran.sqlite',
      'assets/quran.sqlite',
      'quran.sqlite'
    ];
    
    for (final path in paths) {
      try {
        final data = await rootBundle.load(path);
        print('Successfully loaded asset at path: $path (${data.lengthInBytes} bytes)');
      } catch (e) {
        print('Failed to load asset at path: $path - $e');
      }
    }
  } catch (e) {
    print('Error during asset debugging: $e');
  }
}
```

## Contact Support

If you continue to experience issues after trying these solutions, please contact our support team with the following information:

1. Your Flutter version (`flutter --version`)
2. Your device/emulator information
3. Complete error logs from the console
4. Screenshots of the error 