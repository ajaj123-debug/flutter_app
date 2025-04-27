import 'package:googleapis/sheets/v4.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'dart:io';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:logging/logging.dart' as logging;
import 'package:shared_preferences/shared_preferences.dart';

class GoogleSheetsExportService {
  static final _logger = logging.Logger('GoogleSheetsExportService');
  static const String _apiKey = 'AIzaSyDZZmfYFIy5anY8K0kqPJse_-TfiKhugVo';
  static const String _serviceAccountEmail =
      'itwafund@able-stock-453111-f7.iam.gserviceaccount.com';
  static const String _userEmail = 'ajaj42699@gmail.com';
  SheetsApi? _sheetsApi;
  drive.DriveApi? _driveApi;
  String? _spreadsheetId;
  static const List<String> _scopes = [
    'https://www.googleapis.com/auth/spreadsheets',
    'https://www.googleapis.com/auth/drive.file',
  ];
  bool _isInitialized = false;

  GoogleSheetsExportService() {
    _logger.info('GoogleSheetsExportService initialized');
  }

  Future<bool> _checkInternetConnection() async {
    _logger.info('Checking internet connection...');
    try {
      final result = await InternetAddress.lookup('google.com');
      final hasConnection =
          result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      _logger.info('Internet connection check result: $hasConnection');
      return hasConnection;
    } on SocketException catch (e) {
      _logger.warning('Internet connection check failed: ${e.message}');
      return false;
    }
  }

  Future<ServiceAccountCredentials> _getCredentials() async {
    _logger.info('Loading service account credentials...');
    try {
      final jsonString =
          await rootBundle.loadString('assets/service_account.json');
      _logger.info('Successfully loaded service_account.json');

      final jsonMap = json.decode(jsonString);
      _logger.info('Successfully parsed service account JSON');

      final credentials = ServiceAccountCredentials.fromJson(jsonMap);
      _logger.info('Successfully created ServiceAccountCredentials');

      return credentials;
    } catch (e, stackTrace) {
      _logger.severe(
          'Error loading service account credentials', e, stackTrace);
      rethrow;
    }
  }

  Future<void> initialize() async {
    _logger.info('Initializing Google Sheets service...');
    if (_isInitialized) {
      _logger.info('Service already initialized');
      return;
    }

    try {
      _logger.info('Checking internet connection...');
      if (!await _checkInternetConnection()) {
        throw Exception('No internet connection available');
      }

      _logger.info('Getting credentials...');
      final credentials = await _getCredentials();

      _logger.info('Creating auth client...');
      final authClient = await clientViaServiceAccount(
        credentials,
        _scopes,
      );

      _logger.info('Creating Sheets API client...');
      _sheetsApi = SheetsApi(authClient);

      _logger.info('Creating Drive API client...');
      _driveApi = drive.DriveApi(authClient);

      _isInitialized = true;
      _logger.info('Google Sheets service initialized Successfully');
    } catch (e, stackTrace) {
      _logger.severe('Error initializing Sheets API', e, stackTrace);
      _isInitialized = false;
      rethrow;
    }
  }

  static const List<String> _defaultShareEmails = [
    'ajaj42699@gmail.com',
    // Add more emails here if needed
  ];

  Future<void> _shareSpreadsheetWithUsers(String spreadsheetId) async {
    for (String email in _defaultShareEmails) {
      _logger.info('Sharing spreadsheet with user: $email');
      try {
        final permission = drive.Permission()
          ..type = 'user'
          ..role = 'writer'
          ..emailAddress = email;

        await _driveApi!.permissions.create(
          permission,
          spreadsheetId,
          sendNotificationEmail: true,
        );

        _logger.info('Successfully shared spreadsheet with $email');
      } catch (e, stackTrace) {
        _logger.severe('Error sharing spreadsheet with $email', e, stackTrace);
      }
    }
  }

  Future<String> createNewSpreadsheet(String mosqueName) async {
    _logger.info('Creating new spreadsheet for mosque: $mosqueName');
    if (!_isInitialized) {
      _logger.info('Service not initialized, initializing now...');
      await initialize();
    }

    try {
      _logger.info('Creating spreadsheet properties...');
      final properties = SpreadsheetProperties()
        ..title = '$mosqueName - Mosque Management';
      final spreadsheet = Spreadsheet()..properties = properties;

      _logger.info('Sending create spreadsheet request...');
      final response = await _sheetsApi!.spreadsheets.create(spreadsheet);
      final spreadsheetId = response.spreadsheetId!;

      _logger.info('Sharing spreadsheet with user...');
      await _shareSpreadsheetWithUsers(spreadsheetId);

      _logger.info('Saving spreadsheet ID to preferences...');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('mosque_sheet_$mosqueName', spreadsheetId);

      _logger.info('Created new spreadsheet with ID: $spreadsheetId');
      return spreadsheetId;
    } catch (e, stackTrace) {
      _logger.severe('Error creating spreadsheet', e, stackTrace);
      rethrow;
    }
  }

  Future<String> getOrCreateSpreadsheetId(String mosqueName) async {
    _logger.info('Getting or creating spreadsheet ID for mosque: $mosqueName');
    if (!_isInitialized) {
      _logger.info('Service not initialized, initializing now...');
      await initialize();
    }

    try {
      _logger.info('Getting spreadsheet ID from preferences...');
      final prefs = await SharedPreferences.getInstance();
      final spreadsheetId = prefs.getString('mosque_sheet_$mosqueName');

      if (spreadsheetId == null || spreadsheetId.isEmpty) {
        _logger.info(
            'No existing spreadsheet ID found, creating new spreadsheet...');
        return await createNewSpreadsheet(mosqueName);
      }

      // Verify the spreadsheet exists and is accessible
      try {
        _logger.info('Verifying spreadsheet access...');
        await _sheetsApi!.spreadsheets.get(spreadsheetId);
        _logger.info('Found existing spreadsheet ID: $spreadsheetId');
        return spreadsheetId;
      } catch (e) {
        _logger.warning(
            'Existing spreadsheet not accessible, creating new one...');
        return await createNewSpreadsheet(mosqueName);
      }
    } catch (e, stackTrace) {
      _logger.severe('Error getting or creating spreadsheet ID', e, stackTrace);
      rethrow;
    }
  }

  Future<void> exportData(
      String mosqueName, List<List<dynamic>> data, String sheetName) async {
    _logger.info('Exporting data to sheet: $sheetName for mosque: $mosqueName');
    if (!_isInitialized) {
      _logger.info('Service not initialized, initializing now...');
      await initialize();
    }

    try {
      _logger.info('Getting spreadsheet ID...');
      final spreadsheetId = await getOrCreateSpreadsheetId(mosqueName);

      _logger.info('Creating sheet if not exists...');
      await _createSheetIfNotExists(spreadsheetId, sheetName);

      _logger.info('Preparing data for export...');
      final valueRange = ValueRange()..values = data;

      _logger.info('Updating sheet with data...');
      await _sheetsApi!.spreadsheets.values.update(
        valueRange,
        spreadsheetId,
        '$sheetName!A1',
        valueInputOption: 'USER_ENTERED',
      );

      _logger.info('Data exported Successfully to sheet: $sheetName');
    } catch (e, stackTrace) {
      _logger.severe('Error exporting data', e, stackTrace);
      rethrow;
    }
  }

  Future<void> _createSheetIfNotExists(
      String spreadsheetId, String sheetName) async {
    _logger.info('Checking if sheet exists: $sheetName');
    try {
      _logger.info('Attempting to get sheet data...');
      await _sheetsApi!.spreadsheets.values.get(
        spreadsheetId,
        '$sheetName!A1',
      );
      _logger.info('Sheet exists: $sheetName');
    } catch (e) {
      _logger.info('Sheet does not exist, creating new sheet: $sheetName');
      try {
        _logger.info('Creating sheet properties...');
        final sheetProperties = SheetProperties()..title = sheetName;
        final addSheetRequest = AddSheetRequest()..properties = sheetProperties;

        _logger.info('Preparing batch update request...');
        final batchUpdateRequest = BatchUpdateSpreadsheetRequest()
          ..requests = [
            Request()..addSheet = addSheetRequest,
          ];

        _logger.info('Sending batch update request...');
        await _sheetsApi!.spreadsheets.batchUpdate(
          batchUpdateRequest,
          spreadsheetId,
        );

        _logger.info('Created new sheet Successfully: $sheetName');
      } catch (e, stackTrace) {
        _logger.severe('Error creating sheet', e, stackTrace);
        rethrow;
      }
    }
  }

  Future<ValueRange> getSheetData(
      String mosqueName, String sheetName, String range) async {
    _logger.info('Getting data from sheet: $sheetName, range: $range');
    if (!_isInitialized) {
      _logger.info('Service not initialized, initializing now...');
      await initialize();
    }

    try {
      _logger.info('Getting spreadsheet ID...');
      final spreadsheetId = await getOrCreateSpreadsheetId(mosqueName);

      _logger.info('Getting sheet data...');
      final response = await _sheetsApi!.spreadsheets.values.get(
        spreadsheetId,
        '$sheetName!$range',
      );

      _logger.info('Successfully retrieved sheet data');
      return response;
    } catch (e, stackTrace) {
      _logger.severe('Error getting sheet data', e, stackTrace);
      rethrow;
    }
  }

  // Make _sheetsApi accessible for data recovery
  SheetsApi get sheetsApi {
    if (!_isInitialized || _sheetsApi == null) {
      throw Exception('Google Sheets service not initialized');
    }
    return _sheetsApi!;
  }
}
