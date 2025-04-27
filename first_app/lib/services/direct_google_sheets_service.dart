import 'package:googleapis/sheets/v4.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'dart:io';
import 'dart:convert';
import 'package:logging/logging.dart' as logging;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'database_service.dart';

class DirectGoogleSheetsService {
  static final _logger = logging.Logger('DirectGoogleSheetsService');
  SheetsApi? _sheetsApi;
  drive.DriveApi? _driveApi;
  static const List<String> _scopes = [
    'https://www.googleapis.com/auth/spreadsheets',
    'https://www.googleapis.com/auth/drive.file',
  ];
  bool _isInitialized = false;
  static const String _recoverySheetName = 'Recovery_Data';
  String? _apiKey;

  DirectGoogleSheetsService() {
    _logger.info('DirectGoogleSheetsService initialized');
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

  Future<ServiceAccountCredentials> _getCredentialsFromFile(
      String filePath) async {
    _logger.info('Loading service account credentials from file: $filePath');
    try {
      final file = File(filePath);
      final jsonString = await file.readAsString();
      _logger.info('Successfully loaded service account JSON from file');

      final jsonMap = json.decode(jsonString);
      _logger.info('Successfully parsed service account JSON');

      final credentials = ServiceAccountCredentials.fromJson(jsonMap);
      _logger.info('Successfully created ServiceAccountCredentials');

      return credentials;
    } catch (e, stackTrace) {
      _logger.severe(
          'Error loading service account credentials from file', e, stackTrace);
      rethrow;
    }
  }

  Future<void> initialize(String serviceAccountPath, String apiKey) async {
    _logger.info('Initializing Direct Google Sheets service...');
    if (_isInitialized) {
      _logger.info('Service already initialized');
      return;
    }

    try {
      _logger.info('Checking internet connection...');
      if (!await _checkInternetConnection()) {
        throw Exception('No internet connection available');
      }

      _apiKey = apiKey;
      _logger.info('API Key set: ${_apiKey != null ? 'Yes' : 'No'}');

      _logger.info('Getting credentials from file...');
      final credentials = await _getCredentialsFromFile(serviceAccountPath);

      _logger.info('Creating auth client...');
      final authClient = await clientViaServiceAccount(
        credentials,
        _scopes,
      );

      // Create an API key-enabled HTTP client by wrapping the auth client
      final apiKeyClient = _ApiKeyHttpClient(authClient, apiKey);

      _logger.info('Creating Sheets API client...');
      _sheetsApi = SheetsApi(apiKeyClient);

      _logger.info('Creating Drive API client...');
      _driveApi = drive.DriveApi(apiKeyClient);

      _isInitialized = true;
      _logger.info('Direct Google Sheets service initialized Successfully');
    } catch (e, stackTrace) {
      _logger.severe('Error initializing Direct Sheets API', e, stackTrace);
      _isInitialized = false;
      rethrow;
    }
  }

  Future<void> _shareSpreadsheetWithUsers(
      String spreadsheetId, List<String> emails) async {
    for (String email in emails) {
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
        // Continue sharing with other emails even if one fails
      }
    }
  }

  Future<String> createNewSpreadsheet(
      String mosqueName, List<String> shareWithEmails) async {
    _logger.info('Creating new spreadsheet for mosque: $mosqueName');
    if (!_isInitialized) {
      throw Exception('Service not initialized. Call initialize() first.');
    }

    try {
      _logger.info('Creating spreadsheet properties...');
      final properties = SpreadsheetProperties()
        ..title = '$mosqueName - Mosque Management';
      final spreadsheet = Spreadsheet()..properties = properties;

      _logger.info('Sending create spreadsheet request...');
      final response = await _sheetsApi!.spreadsheets.create(spreadsheet);
      final spreadsheetId = response.spreadsheetId!;

      _logger.info('Sharing spreadsheet with users...');
      await _shareSpreadsheetWithUsers(spreadsheetId, shareWithEmails);

      _logger.info('Created new spreadsheet with ID: $spreadsheetId');
      return spreadsheetId;
    } catch (e, stackTrace) {
      _logger.severe('Error creating spreadsheet', e, stackTrace);
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
        _logger.info('Successfully created sheet: $sheetName');
      } catch (e, stackTrace) {
        _logger.severe('Error creating sheet', e, stackTrace);
        rethrow;
      }
    }
  }

  String _getShortTransactionType(String fullType) {
    switch (fullType) {
      case 'TransactionType.income':
        return 'TxnTyp.inc';
      case 'TransactionType.deduction':
        return 'TxnTyp.ded';
      default:
        return fullType;
    }
  }

  String _getFullTransactionType(String shortType) {
    switch (shortType) {
      case 'TxnTyp.inc':
        return 'TransactionType.income';
      case 'TxnTyp.ded':
        return 'TransactionType.deduction';
      default:
        return shortType;
    }
  }

  Future<void> createRecoveryData(String spreadsheetId, String securityKey,
      DatabaseService databaseService) async {
    _logger.info('Creating recovery data using direct Sheets API...');
    if (!_isInitialized) {
      throw Exception('Service not initialized. Call initialize() first.');
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final mosqueName = prefs.getString('masjid_name');

      if (mosqueName == null || mosqueName.isEmpty) {
        _logger.warning('No mosque name found for recovery');
        return;
      }

      // Get data from all tables
      final payers = await databaseService.getAllPayers();
      final transactions = await databaseService.getAllTransactions();
      final categories = await databaseService.getAllCategories();

      // Prepare data for recovery
      final recoveryData = <List<dynamic>>[
        ['Table', 'Data'], // Header row for non-transaction tables
        [
          'Table',
          'ID',
          'Payer ID',
          'Amount',
          'Type',
          'Category',
          'Date'
        ], // Header row for transactions
      ];

      // 1. Payers table
      final payersData = payers.map((p) => p.name).join(',');
      recoveryData.add(['Payers', payersData]);

      // 2. Transactions table - one row per transaction
      for (var transaction in transactions) {
        recoveryData.add([
          'Transactions',
          transaction.id.toString(),
          transaction.payerId.toString(),
          transaction.amount.toString(),
          _getShortTransactionType(transaction.type.toString()),
          transaction.category,
          transaction.date.toUtc().toIso8601String(),
        ]);
      }

      // 3. Categories table
      final categoriesData = categories.map((c) => c.name).join(',');
      recoveryData.add(['Categories', categoriesData]);

      // 4. App Settings and Security Key
      final reportHeader = prefs.getString('report_header') ?? '';
      recoveryData.add([
        'Settings',
        'masjid_name=$mosqueName,report_header=$reportHeader,security_key=$securityKey'
      ]);

      // Create recovery sheet if it doesn't exist
      await _createSheetIfNotExists(spreadsheetId, _recoverySheetName);

      // Write data to the recovery sheet
      _logger.info('Writing recovery data to sheet...');
      final valueRange = ValueRange()..values = recoveryData;

      await _sheetsApi!.spreadsheets.values.update(
        valueRange,
        spreadsheetId,
        '$_recoverySheetName!A1',
        valueInputOption: 'USER_ENTERED',
      );

      _logger.info('Recovery data created Successfully');
    } catch (e, stackTrace) {
      _logger.severe('Error creating recovery data', e, stackTrace);
      rethrow;
    }
  }

  Future<void> restoreFromRecoveryData(String spreadsheetId, String securityKey,
      DatabaseService databaseService) async {
    _logger.info('Starting data recovery from spreadsheet ID: $spreadsheetId');
    if (!_isInitialized) {
      throw Exception('Service not initialized. Call initialize() first.');
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final mosqueName = prefs.getString('masjid_name');

      if (mosqueName == null || mosqueName.isEmpty) {
        _logger.warning('No mosque name found for recovery');
        return;
      }

      // Get data from recovery sheet
      _logger.info('Fetching recovery data from sheet...');
      final response = await _sheetsApi!.spreadsheets.values.get(
        spreadsheetId,
        '$_recoverySheetName!A1:G1000',
      );

      if (response.values == null || response.values!.isEmpty) {
        _logger.warning('No recovery data found in sheet');
        return;
      }

      String? storedSecurityKey;
      final db = await databaseService.database;
      await db.transaction((txn) async {
        // Clear existing data
        _logger.info('Clearing existing data...');
        await txn.delete('payers');
        await txn.delete('transactions');
        await txn.delete('categories');

        // Restore data from recovery sheet
        _logger.info('Restoring data from recovery sheet...');
        for (var row in response.values!) {
          if (row.isEmpty) continue;

          final tableName = row[0] as String;

          // Skip header rows
          if (tableName == 'Table' && row.length > 1 && row[1] == 'Data') {
            continue;
          }
          if (tableName == 'Table' && row.length > 1 && row[1] == 'ID') {
            continue;
          }

          switch (tableName) {
            case 'Payers':
              if (row.length >= 2) {
                final payers = (row[1] as String).split(',');
                for (var payer in payers) {
                  await txn.insert('payers', {'name': payer});
                }
              }
              break;

            case 'Transactions':
              if (row.length >= 7) {
                try {
                  final dateStr = row[6] as String;
                  final date = DateTime.parse(dateStr).toLocal();
                  await txn.insert('transactions', {
                    'id': int.parse(row[1].toString()),
                    'payer_id': int.parse(row[2].toString()),
                    'amount': double.parse(row[3].toString()),
                    'type': _getFullTransactionType(row[4] as String),
                    'category': row[5],
                    'date': date.toIso8601String(),
                  });
                } catch (e) {
                  _logger.warning(
                      'Error parsing transaction date: ${row[6]}', e);
                  continue;
                }
              }
              break;

            case 'Categories':
              if (row.length >= 2) {
                final categories = (row[1] as String).split(',');
                for (var category in categories) {
                  await txn.insert('categories', {'name': category});
                }
              }
              break;

            case 'Settings':
              if (row.length >= 2) {
                final settings = (row[1] as String).split(',');
                for (var setting in settings) {
                  final parts = setting.split('=');
                  if (parts.length == 2) {
                    switch (parts[0]) {
                      case 'masjid_name':
                        await prefs.setString('masjid_name', parts[1]);
                        break;
                      case 'report_header':
                        await prefs.setString('report_header', parts[1]);
                        break;
                      case 'security_key':
                        storedSecurityKey = parts[1];
                        break;
                    }
                  }
                }
              }
              break;
          }
        }
      });

      // Verify security key
      if (storedSecurityKey == null || storedSecurityKey != securityKey) {
        throw Exception('Invalid security key. Recovery failed.');
      }

      _logger.info('Data restored successfully');
    } catch (e, stackTrace) {
      _logger.severe('Error restoring data', e, stackTrace);
      rethrow;
    }
  }

  Future<void> exportData(
      String mosqueName, List<List<dynamic>> data, String sheetName) async {
    _logger.info('Exporting data to sheet: $sheetName for mosque: $mosqueName');
    if (!_isInitialized) {
      throw Exception('Service not initialized. Call initialize() first.');
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final spreadsheetId = prefs.getString('mosque_sheet_$mosqueName');

      if (spreadsheetId == null || spreadsheetId.isEmpty) {
        _logger.warning('No spreadsheet ID found for mosque: $mosqueName');
        return;
      }

      // Create the sheet if it doesn't exist
      await _createSheetIfNotExists(spreadsheetId, sheetName);

      // Prepare the data
      final valueRange = ValueRange()..values = data;

      // Update the sheet with data
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
}

// Custom HTTP client that adds API key to all requests
class _ApiKeyHttpClient extends http.BaseClient {
  final http.Client _inner;
  final String _apiKey;

  _ApiKeyHttpClient(this._inner, this._apiKey);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    // Add API key as a query parameter to all requests
    final url = request.url;
    final newUri = url.replace(
      queryParameters: {
        ...url.queryParameters,
        'key': _apiKey,
      },
    );
    request = http.Request(request.method, newUri)
      ..headers.addAll(request.headers)
      ..followRedirects = request.followRedirects
      ..persistentConnection = request.persistentConnection
      ..maxRedirects = request.maxRedirects;

    if (request is http.Request) {
      (request as http.Request).bodyBytes = (request as http.Request).bodyBytes;
    }

    return _inner.send(request);
  }
}
