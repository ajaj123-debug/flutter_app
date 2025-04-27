import 'package:logging/logging.dart' as logging;
import 'package:shared_preferences/shared_preferences.dart';
import 'database_service.dart';
import 'script_based_export_service.dart';

class ScriptBasedRecoveryService {
  static final _logger = logging.Logger('ScriptBasedRecoveryService');
  final DatabaseService _databaseService;
  final ScriptBasedExportService _scriptService;

  ScriptBasedRecoveryService({
    required DatabaseService databaseService,
    required ScriptBasedExportService scriptService,
  })  : _databaseService = databaseService,
        _scriptService = scriptService;

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

  Future<String> createNewMosqueSpreadsheet(String mosqueName) async {
    _logger.info('Creating new mosque spreadsheet: $mosqueName');
    try {
      return await _scriptService.createNewSpreadsheet(mosqueName);
    } catch (e) {
      _logger.severe('Error creating new mosque spreadsheet', e);
      rethrow;
    }
  }

  Future<void> createRecoveryData(String spreadsheetId, String securityKey) async {
    _logger.info('Creating recovery data using script-based approach...');
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

      // Prepare data for recovery - use consistent 2-column format
      final recoveryData = <List<dynamic>>[
        ['Table', 'Data'], // Header row
      ];

      // 1. Payers table
      final payersData = payers.map((p) => p.name).join(',');
      recoveryData.add(['Payers', payersData]);

      // 2. Transactions table - combine each transaction into a single data cell with format:
      // ID|PayerID|Amount|Type|Category|Date
      for (var transaction in transactions) {
        final transactionData = [
          transaction.id.toString(),
          transaction.payerId.toString(),
          transaction.amount.toString(),
          _getShortTransactionType(transaction.type.toString()),
          transaction.category,
          transaction.date.toUtc().toIso8601String(),
        ].join('|');
        
        recoveryData.add(['Transactions', transactionData]);
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

      // Write data to the recovery sheet using script service
      _logger.info('Writing recovery data to sheet using script service...');
      final success = await _scriptService.saveRecoveryData(spreadsheetId, recoveryData);
      
      if (success) {
        _logger.info('Recovery data created successfully');
      } else {
        _logger.warning('Failed to create recovery data');
      }
    } catch (e) {
      _logger.warning('Failed to create recovery data', e);
    }
  }

  Future<void> restoreFromRecoveryData(String spreadsheetId, String securityKey) async {
    _logger.info('Starting data recovery using script-based approach from spreadsheet ID: $spreadsheetId');
    try {
      final prefs = await SharedPreferences.getInstance();
      final mosqueName = prefs.getString('masjid_name');

      if (mosqueName == null || mosqueName.isEmpty) {
        _logger.warning('No mosque name found for recovery');
        return;
      }

      // Get recovery data from the script service
      _logger.info('Fetching recovery data from sheet using script service...');
      final recoveryData = await _scriptService.getRecoveryData(spreadsheetId);

      if (recoveryData.isEmpty) {
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
        for (var row in recoveryData) {
          if (row.isEmpty) continue;

          // Skip header row
          if (row.length > 1 && row[0] == 'Table' && row[1] == 'Data') {
            continue;
          }

          if (row.length < 2) {
            _logger.warning('Skipping invalid row: $row');
            continue;
          }

          final tableName = row[0] as String;
          final data = row[1] as String;

          switch (tableName) {
            case 'Payers':
              final payers = data.split(',');
              for (var payer in payers) {
                if (payer.trim().isNotEmpty) {
                  await txn.insert('payers', {'name': payer.trim()});
                }
              }
              break;

            case 'Transactions':
              // Parse the pipe-delimited transaction data
              final parts = data.split('|');
              if (parts.length >= 6) {
                try {
                  final id = int.parse(parts[0]);
                  final payerId = int.parse(parts[1]);
                  final amount = double.parse(parts[2]);
                  final type = _getFullTransactionType(parts[3]);
                  final category = parts[4];
                  final dateStr = parts[5];
                  final date = DateTime.parse(dateStr).toLocal();
                  
                  await txn.insert('transactions', {
                    'id': id,
                    'payer_id': payerId,
                    'amount': amount,
                    'type': type,
                    'category': category,
                    'date': date.toIso8601String(),
                  });
                } catch (e) {
                  _logger.warning('Error parsing transaction: $data', e);
                  continue;
                }
              }
              break;

            case 'Categories':
              final categories = data.split(',');
              for (var category in categories) {
                if (category.trim().isNotEmpty) {
                  await txn.insert('categories', {'name': category.trim()});
                }
              }
              break;

            case 'Settings':
              final settings = data.split(',');
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
              break;
          }
        }
      });

      // Verify security key
      if (storedSecurityKey == null || storedSecurityKey != securityKey) {
        throw Exception('Invalid security key. Recovery failed.');
      }

      _logger.info('Data restored successfully');
    } catch (e) {
      _logger.severe('Error restoring data', e);
      rethrow;
    }
  }
} 