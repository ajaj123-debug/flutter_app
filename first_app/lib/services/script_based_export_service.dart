import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart' as logging;
import 'package:shared_preferences/shared_preferences.dart';

class ScriptBasedExportService {
  static final _logger = logging.Logger('ScriptBasedExportService');
  static const String _scriptUrl =
      'https://script.google.com/macros/s/AKfycbwe-28aFZ-bPzDYgYH5iFEKwrP8nNYIp_afrdNVHuoNQTt81sFhW5o5mbqdEAF0TPt-/exec';

  ScriptBasedExportService() {
    _logger.info('ScriptBasedExportService initialized');
  }

  Future<Map<String, dynamic>> _makeRequestWithRedirects(
      String action, Map<String, dynamic> body) async {
    final client = http.Client();
    int retryCount = 0;
    const maxRetries = 2;

    try {
      _logger.info('Making $action request with redirection support');

      while (retryCount <= maxRetries) {
        final headers = {
          'Content-Type': 'application/json',
          'X-Retry-Count': '$retryCount',
        };

        _logger.info(
            '$action attempt ${retryCount + 1}/${maxRetries + 1} with headers: $headers');

        var response = await client.post(
          Uri.parse(_scriptUrl),
          headers: headers,
          body: jsonEncode(body),
        );

        _logger.info('$action API response status: ${response.statusCode}');

        if (response.statusCode == 302 &&
            response.headers.containsKey('location')) {
          final redirectUrl = response.headers['location']!;
          _logger.info('Following redirect to: $redirectUrl');

          response = await client.get(Uri.parse(redirectUrl));
          _logger.info('Redirect response status: ${response.statusCode}');
        }

        final bodyPreview = response.body.length > 200
            ? '${response.body.substring(0, 200)}...(truncated)'
            : response.body;
        _logger.info('$action API response body preview: $bodyPreview');

        if (response.statusCode == 200) {
          if (response.body.trim().startsWith('<')) {
            _logger.warning('Received HTML response instead of JSON');

            if (retryCount < maxRetries) {
              retryCount++;
              continue;
            }

            return {'success': false, 'error': 'HTML response received'};
          }

          try {
            final jsonData = jsonDecode(response.body);
            return jsonData;
          } catch (e) {
            _logger.severe('Error decoding JSON response: $e');

            if (retryCount < maxRetries) {
              retryCount++;
              continue;
            }

            return {'success': false, 'error': 'Invalid JSON: $e'};
          }
        }

        _logger.warning('Non-OK status code: ${response.statusCode}');

        if (retryCount < maxRetries) {
          retryCount++;
          continue;
        }

        return {
          'success': false,
          'error': 'HTTP status ${response.statusCode}'
        };
      }

      return {'success': false, 'error': 'Exhausted retries'};
    } catch (e) {
      _logger.severe('Network error in $action: $e');
      return {'success': false, 'error': 'Network error: $e'};
    } finally {
      client.close();
    }
  }

  // Create a new spreadsheet for a mosque
  Future<String> createNewSpreadsheet(String mosqueName) async {
    _logger.info('Creating new spreadsheet for mosque: $mosqueName');

    try {
      // Try to get the user's email from preferences
      final prefs = await SharedPreferences.getInstance();
      final userEmail =
          prefs.getString('sheets_user_email') ?? 'ajaj42699@gmail.com';

      final response = await _makeRequestWithRedirects('createNewSpreadsheet', {
        'action': 'createNewSpreadsheet',
        'mosqueName': mosqueName,
        'email': userEmail,
      });

      if (response['success'] == true && response['spreadsheetId'] != null) {
        final spreadsheetId = response['spreadsheetId'];
        _logger
            .info('Successfully created spreadsheet with ID: $spreadsheetId');
        return spreadsheetId;
      }

      throw Exception(
          'Failed to create spreadsheet: ${response['error'] ?? 'Unknown error'}');
    } catch (e) {
      _logger.severe('Error creating spreadsheet', e);
      rethrow;
    }
  }

  // Ensure required sheets exist in the spreadsheet
  Future<bool> ensureRequiredSheetsExist(String spreadsheetId) async {
    _logger
        .info('Ensuring required sheets exist in spreadsheet: $spreadsheetId');

    try {
      // List of required sheets (removed 'Transactions', 'Deductions', and 'FundData_<year>' since they're no longer needed)
      final requiredSheets = [
        'Summary',
        'Recovery_Data',
      ];

      // Create each sheet if it doesn't exist
      for (final sheetName in requiredSheets) {
        await createSheetIfNotExists(spreadsheetId, sheetName);
      }

      _logger.info('Successfully ensured all required sheets exist');
      return true;
    } catch (e) {
      _logger.severe('Error ensuring required sheets exist', e);
      return false;
    }
  }

  // Create a sheet if it doesn't exist
  Future<bool> createSheetIfNotExists(
      String spreadsheetId, String sheetName) async {
    _logger.info(
        'Creating sheet if not exists: $sheetName in spreadsheet: $spreadsheetId');

    try {
      final response =
          await _makeRequestWithRedirects('createSheetIfNotExists', {
        'action': 'createSheetIfNotExists',
        'spreadsheetId': spreadsheetId,
        'sheetName': sheetName,
      });

      if (response['success'] == true) {
        _logger.info('Successfully created or verified sheet: $sheetName');
        return true;
      }

      _logger.warning('Failed to create sheet: ${response['error']}');
      return false;
    } catch (e) {
      _logger.severe('Error creating sheet', e);
      return false;
    }
  }

  // Save recovery data to spreadsheet
  Future<bool> saveRecoveryData(
      String spreadsheetId, List<List<dynamic>> recoveryData) async {
    _logger.info('Saving recovery data to spreadsheet: $spreadsheetId');

    try {
      final response = await _makeRequestWithRedirects('saveRecoveryData', {
        'action': 'saveRecoveryData',
        'spreadsheetId': spreadsheetId,
        'recoveryData': recoveryData,
      });

      if (response['success'] == true) {
        _logger.info('Successfully saved recovery data');
        return true;
      }

      _logger.warning('Failed to save recovery data: ${response['error']}');
      return false;
    } catch (e) {
      _logger.severe('Error saving recovery data', e);
      return false;
    }
  }

  // Get recovery data for restoration
  Future<List<List<dynamic>>> getRecoveryData(String spreadsheetId) async {
    _logger.info('Getting recovery data from spreadsheet: $spreadsheetId');

    try {
      final response =
          await _makeRequestWithRedirects('getRecoveryDataForRestoration', {
        'action': 'getRecoveryDataForRestoration',
        'spreadsheetId': spreadsheetId,
      });

      if (response['success'] == true) {
        final List<List<dynamic>> data = List<List<dynamic>>.from(
            response['data'].map((row) => List<dynamic>.from(row)));
        _logger
            .info('Successfully retrieved recovery data: ${data.length} rows');
        return data;
      }

      _logger.warning('Failed to get recovery data: ${response['error']}');
      return [];
    } catch (e) {
      _logger.severe('Error getting recovery data', e);
      return [];
    }
  }

  // Export data to a sheet in the spreadsheet
  Future<bool> exportData(
      String mosqueName, List<List<dynamic>> data, String sheetName) async {
    _logger.info('Exporting data to sheet: $sheetName for mosque: $mosqueName');

    try {
      // Get the spreadsheet ID from preferences
      final prefs = await SharedPreferences.getInstance();
      final spreadsheetId = prefs.getString('mosque_sheet_$mosqueName');

      if (spreadsheetId == null || spreadsheetId.isEmpty) {
        _logger.warning('No spreadsheet ID found for mosque: $mosqueName');
        return false;
      }

      final response = await _makeRequestWithRedirects('exportData', {
        'action': 'exportData',
        'spreadsheetId': spreadsheetId,
        'sheetName': sheetName,
        'data': data,
      });

      if (response['success'] == true) {
        _logger.info('Successfully exported data to sheet: $sheetName');
        return true;
      }

      _logger.warning('Failed to export data: ${response['error']}');
      return false;
    } catch (e) {
      _logger.severe('Error exporting data', e);
      return false;
    }
  }
}
