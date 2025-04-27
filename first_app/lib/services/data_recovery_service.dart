import 'package:logging/logging.dart' as logging;
import 'package:shared_preferences/shared_preferences.dart';
import 'database_service.dart';
import 'google_sheets_export_service.dart';

class DataRecoveryService {
  static final _logger = logging.Logger('DataRecoveryService');
  static const String _recoverySheetName = 'Recovery_Data';
  final DatabaseService _databaseService;
  final GoogleSheetsExportService _sheetsService;

  DataRecoveryService({
    required DatabaseService databaseService,
    required GoogleSheetsExportService sheetsService,
  })  : _databaseService = databaseService,
        _sheetsService = sheetsService;

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

  Future<void> createRecoveryData(String securityKey) async {
    _logger.info('Creating recovery data...');
    try {
      final prefs = await SharedPreferences.getInstance();
      final mosqueName = prefs.getString('masjid_name');

      if (mosqueName == null || mosqueName.isEmpty) {
        _logger.warning('No mosque name found for recovery');
        return;
      }

      // Get data from all tables
      final payers = await _databaseService.getAllPayers();
      final transactions = await _databaseService.getAllTransactions();
      final categories = await _databaseService.getAllCategories();

      // Prepare data for recovery
      final recoveryData = <List<String>>[
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

      // Write data to the recovery sheet
      _logger.info('Writing recovery data to sheet...');
      await _sheetsService.exportData(
          mosqueName, recoveryData, _recoverySheetName);
      _logger.info('SuccessfullyRecovery data created Successfully');
    } catch (e, stackTrace) {
      _logger.severe('Error creating recovery data', e, stackTrace);
      rethrow;
    }
  }

  Future<void> restoreFromRecoveryData(
      String spreadsheetId, String securityKey) async {
    _logger.info('Starting data recovery from spreadsheet ID: $spreadsheetId');
    try {
      final prefs = await SharedPreferences.getInstance();
      final mosqueName = prefs.getString('masjid_name');

      if (mosqueName == null || mosqueName.isEmpty) {
        _logger.warning('No mosque name found for recovery');
        return;
      }

      // Get data from recovery sheet
      _logger.info('Fetching recovery data from sheet...');
      final response = await _sheetsService.getSheetData(
          mosqueName, _recoverySheetName, 'A1:G1000');

      if (response.values == null || response.values!.isEmpty) {
        _logger.warning('No recovery data found in sheet');
        return;
      }

      String? storedSecurityKey;
      final db = await _databaseService.database;
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

      _logger.info('Successfully Data restored successfully');
    } catch (e, stackTrace) {
      _logger.severe('Error restoring data', e, stackTrace);
      rethrow;
    }
  }
}
