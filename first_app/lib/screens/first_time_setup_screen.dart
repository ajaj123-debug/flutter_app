import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logging/logging.dart' as logging;
import '../services/database_service.dart';
import '../services/script_based_export_service.dart';
import '../services/script_based_recovery_service.dart';
import '../services/direct_google_sheets_service.dart';
import 'manager_main_screen.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';

class FirstTimeSetupScreen extends StatefulWidget {
  const FirstTimeSetupScreen({Key? key}) : super(key: key);

  @override
  State<FirstTimeSetupScreen> createState() => _FirstTimeSetupScreenState();
}

class _FirstTimeSetupScreenState extends State<FirstTimeSetupScreen> {
  static final _logger = logging.Logger('FirstTimeSetupScreen');
  final _formKey = GlobalKey<FormState>();
  final _mosqueNameController = TextEditingController();
  final _spreadsheetIdController = TextEditingController();
  final _securityKeyController = TextEditingController();
  final _emailController = TextEditingController();
  final _apiKeyController = TextEditingController();
  bool _isRecoveryMode = false;
  bool _isLoading = false;
  bool _isOfflineRecovery = false;
  bool _isAdvancedSetup = false;
  String? _selectedBackupPath;
  String? _selectedServiceAccountPath;
  late final ScriptBasedExportService _scriptService;
  late final ScriptBasedRecoveryService _recoveryService;
  DirectGoogleSheetsService? _directSheetsService;

  @override
  void initState() {
    super.initState();
    _scriptService = ScriptBasedExportService();
    _recoveryService = ScriptBasedRecoveryService(
      databaseService: DatabaseService.instance,
      scriptService: _scriptService,
    );
    // Request permissions when the screen loads
    _requestPermissions();
  }

  @override
  void dispose() {
    _mosqueNameController.dispose();
    _spreadsheetIdController.dispose();
    _securityKeyController.dispose();
    _emailController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _requestPermissions() async {
    _logger.info('Requesting permissions');

    // Request multiple permissions
    Map<Permission, PermissionStatus> statuses = await [
      Permission.storage,
      Permission.manageExternalStorage,
    ].request();

    _logger.info('Permission statuses: $statuses');

    // Check if we have permission
    if (statuses[Permission.storage] == PermissionStatus.granted ||
        statuses[Permission.manageExternalStorage] ==
            PermissionStatus.granted) {
      _logger.info('Storage permissions granted');
    } else {
      _logger.warning('Storage permissions denied');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Storage permissions are required to access backup files'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _handleNewSetup() async {
    setState(() {
      _isRecoveryMode = false;
      _isOfflineRecovery = false;
      _selectedBackupPath = null;
      _selectedServiceAccountPath = null;
      _spreadsheetIdController.clear();
      _securityKeyController.clear();
    });
  }

  Future<void> _handleRecovery() async {
    setState(() {
      _isRecoveryMode = true;
      _isOfflineRecovery = false;
      _selectedBackupPath = null;
    });
  }

  Future<void> _handleOfflineRecovery() async {
    setState(() {
      _isRecoveryMode = true;
      _isOfflineRecovery = true;
      _selectedBackupPath = null;
    });

    // Small delay to ensure state is updated before showing file picker
    await Future.delayed(const Duration(milliseconds: 100));
    await _searchAndPickBackupFile();
  }

  Future<void> _searchAndPickBackupFile() async {
    try {
      _logger.info('Starting custom backup file search');
      setState(() => _isLoading = true);

      // Define locations to search for backup files
      List<Directory> searchDirectories = [];
      List<String> backupFiles = [];

      // Add common locations to check
      if (Platform.isAndroid) {
        // Primary storage - Downloads folder
        searchDirectories.add(Directory('/storage/emulated/0/Download'));

        // Primary storage - Documents folder
        searchDirectories.add(Directory('/storage/emulated/0/Documents'));

        // Primary storage - Root folder
        searchDirectories.add(Directory('/storage/emulated/0'));

        // Primary storage - Mosque_Fund folder
        searchDirectories
            .add(Directory('/storage/emulated/0/Download/Mosque_Fund'));

        // Primary storage - Root Mosque_Fund folder
        searchDirectories.add(Directory('/storage/emulated/0/Mosque_Fund'));

        // External storage if available
        try {
          final externalDir = await getExternalStorageDirectory();
          if (externalDir != null) {
            searchDirectories.add(externalDir);
            searchDirectories.add(Directory('${externalDir.path}/Mosque_Fund'));

            // Add parent directory of external storage
            final parentPath = externalDir.path
                .split('/')
                .sublist(0, externalDir.path.split('/').length - 1)
                .join('/');
            searchDirectories.add(Directory(parentPath));
          }
        } catch (e) {
          _logger.warning('Could not access external storage: $e');
        }
      } else {
        // iOS - Documents directory
        final docDir = await getApplicationDocumentsDirectory();
        searchDirectories.add(docDir);
        searchDirectories.add(Directory('${docDir.path}/Mosque_Fund'));
      }

      // Add app document directory
      final appDocDir = await getApplicationDocumentsDirectory();
      searchDirectories.add(appDocDir);

      _logger.info(
          'Searching ${searchDirectories.length} directories for backup files');

      // Search each directory for JSON files
      for (var dir in searchDirectories) {
        try {
          if (await dir.exists()) {
            _logger.info('Searching directory: ${dir.path}');

            final entities = await dir.list().toList();
            _logger.info(
                'Found ${entities.length} files/directories in ${dir.path}');

            for (var entity in entities) {
              // Debug log for every file
              if (entity is File) {
                final lowerPath = entity.path.toLowerCase();
                final fileName = entity.path.split('/').last;

                _logger.info('Checking file: ${entity.path}');

                // Improved detection logic - match any of these patterns
                bool isBackupFile = lowerPath.endsWith('.json') ||
                    lowerPath.contains('backup') ||
                    lowerPath.contains('masjid') ||
                    lowerPath.contains('mosque');

                if (isBackupFile) {
                  _logger.info('Found potential backup file: ${entity.path}');
                  backupFiles.add(entity.path);
                }
              } else if (entity is Directory) {
                // Check for Mosque_Fund subdirectory that might not be in our list
                final dirName = entity.path.split('/').last.toLowerCase();
                if (dirName.contains('mosque') ||
                    dirName.contains('masjid') ||
                    dirName.contains('backup')) {
                  try {
                    _logger.info('Checking subdirectory: ${entity.path}');
                    final subFiles = await entity.list().toList();

                    for (var file in subFiles) {
                      if (file is File &&
                          (file.path.toLowerCase().endsWith('.json') ||
                              file.path.toLowerCase().contains('backup') ||
                              file.path.toLowerCase().contains('masjid') ||
                              file.path.toLowerCase().contains('mosque'))) {
                        _logger.info(
                            'Found potential backup file in subdirectory: ${file.path}');
                        backupFiles.add(file.path);
                      }
                    }
                  } catch (e) {
                    _logger.warning(
                        'Error accessing subdirectory ${entity.path}: $e');
                  }
                }
              }
            }
          }
        } catch (e) {
          _logger.warning('Error accessing directory ${dir.path}: $e');
        }
      }

      // Manually check for the specific file the user mentioned
      final specificPaths = [
        '/storage/emulated/0/Download/Sunni Noori Jama Masjid Itwa_Backup_2025_04_27_154006.json',
        '/storage/emulated/0/Download/Mosque_Fund/Sunni Noori Jama Masjid Itwa_Backup_2025_04_27_154006.json',
        '/storage/emulated/0/Mosque_Fund/Sunni Noori Jama Masjid Itwa_Backup_2025_04_27_154006.json',
        '/storage/emulated/0/Documents/Sunni Noori Jama Masjid Itwa_Backup_2025_04_27_154006.json'
      ];

      for (var path in specificPaths) {
        try {
          final file = File(path);
          if (await file.exists()) {
            _logger.info('Found specific backup file: $path');
            if (!backupFiles.contains(path)) {
              backupFiles.add(path);
            }
          }
        } catch (e) {
          _logger.warning('Error checking specific path $path: $e');
        }
      }

      // Add a fallback to search entire Downloads directory recursively if we still don't have files
      if (backupFiles.isEmpty) {
        _logger.info(
            'No backup files found yet, performing deep search in Downloads');
        try {
          await _deepSearchDirectory(
              Directory('/storage/emulated/0/Download'), backupFiles);
        } catch (e) {
          _logger.warning('Error during deep search: $e');
        }
      }

      setState(() => _isLoading = false);

      _logger.info('Found ${backupFiles.length} potential backup files');

      if (backupFiles.isEmpty) {
        if (mounted) {
          final action = await showDialog<String>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('No Backup Files Found'),
              content: const Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      'No backup files were found in common storage locations.'),
                  SizedBox(height: 12),
                  Text(
                      'You can create a sample backup file for testing, or try again after creating a backup from the settings screen.'),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, 'cancel'),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, 'create_sample'),
                  child: const Text('Create Sample Backup'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, 'search_again'),
                  child: const Text('Search Again'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, 'manual_select'),
                  child: const Text('Select File Manually'),
                ),
              ],
            ),
          );

          if (action == 'create_sample') {
            final sampleBackupPath = await _createSampleBackupFile();
            if (sampleBackupPath != null) {
              await _validateAndProcessBackupFile(sampleBackupPath);
            }
            return;
          } else if (action == 'search_again') {
            await _searchAndPickBackupFile();
            return;
          } else if (action == 'manual_select') {
            await _manuallySelectFile();
            return;
          }
        }
        return;
      }

      // Show the list of found files
      if (mounted) {
        final selectedFile = await _showBackupFilesSelectionDialog(backupFiles);
        if (selectedFile != null) {
          await _validateAndProcessBackupFile(selectedFile);
        }
      }
    } catch (e, stackTrace) {
      setState(() => _isLoading = false);
      _logger.severe('Error searching for backup files', e, stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error searching for backup files: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _deepSearchDirectory(
      Directory directory, List<String> backupFiles,
      {int maxDepth = 3, int currentDepth = 0}) async {
    if (currentDepth >= maxDepth) return;

    try {
      _logger.info(
          'Deep searching directory: ${directory.path} (depth: $currentDepth)');
      final entities = await directory.list().toList();

      for (var entity in entities) {
        if (entity is File) {
          final lowerPath = entity.path.toLowerCase();
          if (lowerPath.endsWith('.json') ||
              lowerPath.contains('backup') ||
              lowerPath.contains('masjid') ||
              lowerPath.contains('mosque')) {
            _logger.info(
                'Deep search found potential backup file: ${entity.path}');
            backupFiles.add(entity.path);
          }
        } else if (entity is Directory && currentDepth < maxDepth) {
          await _deepSearchDirectory(entity, backupFiles,
              maxDepth: maxDepth, currentDepth: currentDepth + 1);
        }
      }
    } catch (e) {
      _logger.warning('Error in deep search at ${directory.path}: $e');
    }
  }

  Future<void> _manuallySelectFile() async {
    try {
      _logger.info('Opening manual file picker');
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        dialogTitle: 'Select Backup File',
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        _logger.info('Manually selected file: ${file.path}');

        if (file.path != null) {
          // For directly selected files, read the content first
          try {
            final selectedFile = File(file.path!);
            final content = await selectedFile.readAsString();

            final jsonData = json.decode(content);
            if (jsonData is Map<String, dynamic> &&
                jsonData.containsKey('mosque_name') &&
                jsonData.containsKey('security_key') &&
                jsonData.containsKey('payers') &&
                jsonData.containsKey('categories') &&
                jsonData.containsKey('transactions')) {
              _logger.info('Manually selected file is valid');
              _processSelectedBackupFile(file.path!);
              return;
            }
          } catch (e) {
            _logger.severe('Error reading manually selected file', e);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error reading file: ${e.toString()}'),
                  backgroundColor: Colors.red,
                  duration: const Duration(seconds: 5),
                ),
              );
            }
            return;
          }
        }
      } else {
        _logger.info('No file selected manually');
      }
    } catch (e, stackTrace) {
      _logger.severe('Error with manual file selection', e, stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error selecting file: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<String?> _showBackupFilesSelectionDialog(
      List<String> backupFiles) async {
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select a Backup File'),
        content: Container(
          width: double.maxFinite,
          height: 300,
          child: ListView.builder(
            itemCount: backupFiles.length,
            itemBuilder: (context, index) {
              final path = backupFiles[index];
              final filename = path.split('/').last;
              File file = File(path);
              String fileSize = '';
              String lastModified = '';

              try {
                if (file.existsSync()) {
                  int size = file.lengthSync();
                  if (size < 1024) {
                    fileSize = '$size B';
                  } else if (size < 1024 * 1024) {
                    fileSize = '${(size / 1024).toStringAsFixed(1)} KB';
                  } else {
                    fileSize =
                        '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
                  }

                  lastModified = DateFormat('dd MMM yyyy, HH:mm')
                      .format(file.lastModifiedSync());
                }
              } catch (e) {
                _logger.warning('Error getting file info: $e');
              }

              return ListTile(
                leading: const Icon(Icons.file_present),
                title: Text(filename),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Size: $fileSize', style: TextStyle(fontSize: 12)),
                    Text('Modified: $lastModified',
                        style: TextStyle(fontSize: 12)),
                    Text(path,
                        style: TextStyle(fontSize: 10),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
                isThreeLine: true,
                onTap: () => Navigator.of(context).pop(path),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _validateAndProcessBackupFile(String filePath) async {
    try {
      setState(() => _isLoading = true);
      _logger.info('Validating backup file: $filePath');

      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('File does not exist: $filePath');
      }

      String fileContent;
      try {
        // First try the standard way
        fileContent = await file.readAsString();
      } catch (e) {
        _logger.warning('Error reading file with standard method: $e');

        // Check if we should try to request permissions
        if (e.toString().contains('Permission denied')) {
          // Request storage permissions
          var status = await Permission.storage.request();
          if (status.isGranted) {
            try {
              fileContent = await file.readAsString();
            } catch (e2) {
              throw Exception(
                  'Still cannot access file after permissions granted: ${e2.toString()}');
            }
          } else {
            // Fall back to manual file selection
            final shouldManuallySelect = await _showManualSelectionDialog();
            if (shouldManuallySelect) {
              await _manuallySelectFile();
            }
            setState(() => _isLoading = false);
            return;
          }
        } else {
          rethrow;
        }
      }

      final jsonData = json.decode(fileContent);

      if (jsonData is! Map<String, dynamic>) {
        throw Exception('File is not a valid JSON object');
      }

      if (!jsonData.containsKey('mosque_name') ||
          !jsonData.containsKey('security_key') ||
          !jsonData.containsKey('payers') ||
          !jsonData.containsKey('categories') ||
          !jsonData.containsKey('transactions')) {
        throw Exception('File is missing required backup fields');
      }

      _logger.info('File validation successful, processing backup');
      _processSelectedBackupFile(filePath);
    } catch (e, stackTrace) {
      _logger.severe('Error validating backup file', e, stackTrace);
      if (mounted) {
        final actionSelected = await _showBackupFileErrorDialog(e.toString());
        if (actionSelected == 'manual_select') {
          await _manuallySelectFile();
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<bool> _showManualSelectionDialog() async {
    if (!mounted) return false;

    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Permission Issue'),
            content: const Text(
                'Cannot access the file due to permission restrictions. Would you like to manually select the backup file?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Select Manually'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<String?> _showBackupFileErrorDialog(String errorMessage) async {
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red, size: 28),
            SizedBox(width: 8),
            Text('Backup File Error'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'There was a problem with the backup file:',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              errorMessage,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'You can select a different file or try again.',
              style: TextStyle(fontSize: 16),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'cancel'),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'manual_select'),
            child: const Text('Select File Manually'),
          ),
        ],
      ),
    );
  }

  void _processSelectedBackupFile(String filePath) {
    setState(() {
      _selectedBackupPath = filePath;
    });

    _readBackupFile(filePath);
  }

  Future<void> _readBackupFile(String filePath) async {
    try {
      final file = File(filePath);
      String jsonString;

      try {
        jsonString = await file.readAsString();
      } catch (e) {
        _logger.warning(
            'Error reading file with standard method in _readBackupFile: $e');

        if (e.toString().contains('Permission denied')) {
          // Try to load the specific file selected directly without normal file access
          return await _manuallySelectFile();
        } else {
          rethrow;
        }
      }

      final backup = json.decode(jsonString) as Map<String, dynamic>;

      if (!backup.containsKey('mosque_name') ||
          !backup.containsKey('security_key') ||
          !backup.containsKey('payers') ||
          !backup.containsKey('categories') ||
          !backup.containsKey('transactions')) {
        throw Exception('Invalid backup file format. Missing required fields.');
      }

      setState(() {
        _mosqueNameController.text = backup['mosque_name'] as String;
        _securityKeyController.text = backup['security_key'] as String;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Backup file loaded successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e, stackTrace) {
      _logger.severe('Error reading backup file', e, stackTrace);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error reading backup file: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );

      setState(() {
        _selectedBackupPath = null;
      });

      // Show a dialog to select file manually
      _showBackupFileErrorDialog(e.toString()).then((value) {
        if (value == 'manual_select') {
          _manuallySelectFile();
        }
      });
    }
  }

  Future<void> _restoreFromOfflineBackup() async {
    if (!mounted || _selectedBackupPath == null) return;

    setState(() => _isLoading = true);

    try {
      final file = File(_selectedBackupPath!);
      String jsonString;

      try {
        if (!await file.exists()) {
          throw Exception('Backup file not found');
        }
        jsonString = await file.readAsString();
      } catch (e) {
        _logger.warning(
            'Error reading file with standard method in _restoreFromOfflineBackup: $e');

        if (e.toString().contains('Permission denied')) {
          final shouldManuallySelect = await _showManualSelectionDialog();
          if (shouldManuallySelect) {
            setState(() => _isLoading = false);
            await _manuallySelectFile();
            return;
          } else {
            throw Exception('Cannot access backup file: Permission denied');
          }
        } else {
          rethrow;
        }
      }

      final backup = json.decode(jsonString) as Map<String, dynamic>;

      if (!backup.containsKey('mosque_name') ||
          !backup.containsKey('security_key') ||
          !backup.containsKey('payers') ||
          !backup.containsKey('categories') ||
          !backup.containsKey('transactions')) {
        throw Exception('Invalid backup file format');
      }

      final mosqueName = backup['mosque_name'] as String;
      final securityKey = backup['security_key'] as String;

      if (mosqueName != _mosqueNameController.text) {
        throw Exception('Mosque name in backup does not match');
      }

      if (securityKey != _securityKeyController.text) {
        throw Exception('Invalid security key');
      }

      final db = await DatabaseService.instance.database;
      await db.transaction((txn) async {
        await txn.delete('payers');
        await txn.delete('transactions');
        await txn.delete('categories');

        final payers = backup['payers'] as List;
        for (var payer in payers) {
          await txn.insert('payers', {
            'name': payer['name'] as String,
          });
        }

        final categories = backup['categories'] as List;
        for (var category in categories) {
          await txn.insert('categories', {
            'name': category['name'] as String,
          });
        }

        final transactions = backup['transactions'] as List;
        for (var transaction in transactions) {
          await txn.insert('transactions', {
            'id': transaction['id'] as int,
            'payer_id': transaction['payer_id'] as int,
            'amount': transaction['amount'] as double,
            'type': transaction['type'] as String,
            'category': transaction['category'] as String,
            'date': transaction['date'] as String,
          });
        }
      });

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('masjid_name', mosqueName);
      await prefs.setString('security_key_$mosqueName', securityKey);

      if (backup.containsKey('report_header')) {
        await prefs.setString(
            'report_header', backup['report_header'] as String);
      }

      await prefs.setBool('first_launch', false);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Data restored successfully from backup file!'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const ManagerMainScreen(),
        ),
      );
    } catch (e, stackTrace) {
      _logger.severe('Error restoring from offline backup', e, stackTrace);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _pickServiceAccountFile() async {
    try {
      _logger.info('Picking service account JSON file');
      setState(() => _isLoading = true);

      // First try with specific file type
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        allowMultiple: false,
      );

      // If no results, try with any file type and filter manually
      if (result == null || result.files.isEmpty) {
        _logger.info(
            'No files selected or JSON files not visible, trying with any file type');
        result = await FilePicker.platform.pickFiles(
          type: FileType.any,
          allowMultiple: false,
        );
      }

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        final path = file.path;
        final String fileName = file.name;

        _logger.info('Selected file: $fileName, path: $path');

        // Check if it's a JSON file by extension or by name
        bool isJsonFile = fileName.toLowerCase().endsWith('.json') ||
            (path?.toLowerCase().endsWith('.json') ?? false);

        _logger.info('Is JSON file by extension check: $isJsonFile');

        if (path != null) {
          // If it doesn't have a .json extension, check the contents
          if (!isJsonFile) {
            _logger
                .info('File does not have .json extension, checking content');
            try {
              final jsonFile = File(path);
              final fileContent = await jsonFile.readAsString();

              // Try to parse as JSON to validate
              final dynamic jsonData = json.decode(fileContent);

              // If we got here, it's valid JSON
              isJsonFile = true;
              _logger.info('File content is valid JSON');
            } catch (e) {
              _logger.warning('File is not valid JSON: $e');
              isJsonFile = false;
            }
          }

          if (isJsonFile) {
            // Additional validation for service account file
            try {
              final jsonFile = File(path);
              final jsonString = await jsonFile.readAsString();
              final jsonData = json.decode(jsonString);

              // Check if it's a valid service account file
              if (jsonData is Map<String, dynamic> &&
                  jsonData['type'] == 'service_account' &&
                  jsonData['project_id'] != null &&
                  jsonData['private_key'] != null &&
                  jsonData['client_email'] != null) {
                setState(() {
                  _selectedServiceAccountPath = path;
                });

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Service account file selected successfully'),
                    backgroundColor: Colors.green,
                  ),
                );
              } else {
                throw Exception(
                    'Invalid service account file format - required fields missing');
              }
            } catch (e) {
              _logger.warning('Invalid service account file: $e');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content:
                      Text('Invalid service account file: ${e.toString()}'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content:
                    Text('Please select a valid JSON service account file'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      } else {
        _logger.info('No file selected');
      }
    } catch (e) {
      _logger.severe('Error picking service account file', e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error selecting file: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleSendData() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final mosqueName = _mosqueNameController.text.trim();
      var spreadsheetId = _spreadsheetIdController.text;
      final securityKey = _securityKeyController.text.trim();

      if (_isAdvancedSetup) {
        // Advanced setup with direct Google Sheets API
        if (_selectedServiceAccountPath == null) {
          throw Exception('Please select a service account JSON file');
        }

        final email = _emailController.text.trim();
        if (email.isEmpty) {
          throw Exception('Please enter your email address for sharing');
        }

        final apiKey = _apiKeyController.text.trim();
        if (apiKey.isEmpty) {
          throw Exception('Please enter your Google Cloud API key');
        }

        // Create direct service
        _directSheetsService = DirectGoogleSheetsService();
        await _directSheetsService!
            .initialize(_selectedServiceAccountPath!, apiKey);

        // Create spreadsheet with direct service
        _logger.info(
            'Creating new spreadsheet using direct service for: $mosqueName');
        try {
          spreadsheetId = await _directSheetsService!.createNewSpreadsheet(
            mosqueName,
            [email], // Share with user's email
          );
          _logger
              .info('Successfully created spreadsheet with ID: $spreadsheetId');
        } catch (e) {
          _logger.severe('Error creating spreadsheet with direct service', e);
          throw Exception(
              'Failed to create spreadsheet: ${e.toString()}. Please check your internet connection and try again.');
        }

        // Save service account path to preferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
            'service_account_path', _selectedServiceAccountPath!);
        await prefs.setBool('using_direct_sheets', true);
        await prefs.setString('sheets_user_email', email);
        await prefs.setString('google_api_key', apiKey);
      } else {
        // Standard setup with script-based service
        _logger.info('Creating new spreadsheet for: $mosqueName');
        try {
          String newSpreadsheetId =
              await _recoveryService.createNewMosqueSpreadsheet(mosqueName);

          // Validate spreadsheet ID doesn't contain underscores
          if (newSpreadsheetId.contains('_')) {
            throw Exception(
                'Generated spreadsheet ID contains underscores. Please try the setup again.');
          }

          // Set the spreadsheet ID to use
          spreadsheetId = newSpreadsheetId;

          // Create recovery data with script service
          await _recoveryService.createRecoveryData(spreadsheetId, securityKey);
        } catch (e) {
          _logger.severe('Error creating spreadsheet with script service', e);
          throw Exception(
              'Failed to create spreadsheet: ${e.toString()}. Please check your internet connection and try again.');
        }

        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('using_direct_sheets', false);
      }

      if (spreadsheetId.contains('_')) {
        if (!mounted) return;
        setState(() => _isLoading = false);

        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red, size: 28),
                SizedBox(width: 8),
                Text('Setup Issue'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'We encountered an issue with the generated secure key.',
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Please try the setup process again. The system will generate a new Secure key.',
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  'This is a temporary issue and should be resolved on the next attempt.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _handleNewSetup();
                },
                child: const Text('Try Again'),
              ),
            ],
          ),
        );
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('masjid_name', mosqueName);
      await prefs.setString('mosque_sheet_$mosqueName', spreadsheetId);
      await prefs.setString('security_key_$mosqueName', securityKey);
      await prefs.setString('mosque_code', spreadsheetId);

      if (_isAdvancedSetup && _directSheetsService != null) {
        // Create recovery data with direct service
        await _directSheetsService!.createRecoveryData(
          spreadsheetId,
          securityKey,
          DatabaseService.instance,
        );
      } else {
        // Create recovery data with script service
        await _recoveryService.createRecoveryData(spreadsheetId, securityKey);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Data sent Successfully! You can now use this Secure key for recovery.'),
          backgroundColor: Colors.green,
        ),
      );

      setState(() {
        _spreadsheetIdController.text = spreadsheetId;
      });
    } catch (e, stackTrace) {
      _logger.severe('Error sending data', e, stackTrace);
      if (!mounted) return;
      setState(() => _isLoading = false);

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red, size: 28),
              SizedBox(width: 8),
              Text('Setup Error'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'We encountered an error during setup:',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                e.toString(),
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Please try the setup process again.',
                style: TextStyle(fontSize: 16),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _handleNewSetup();
              },
              child: const Text('Try Again'),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final mosqueName = _mosqueNameController.text.trim();
      var spreadsheetId = _spreadsheetIdController.text;
      final securityKey = _securityKeyController.text.trim();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('masjid_name', mosqueName);
      await prefs.setString('security_key_$mosqueName', securityKey);

      if (_isRecoveryMode) {
        if (_isOfflineRecovery) {
          if (_selectedBackupPath == null) {
            throw Exception('Please select a backup file first');
          }

          await _restoreFromOfflineBackup();
          return;
        } else {
          if (spreadsheetId.isEmpty) {
            throw Exception('Please enter a Secure key for recovery');
          }

          if (securityKey.isEmpty) {
            throw Exception('Please enter the security key for recovery');
          }

          await prefs.setString('mosque_code', spreadsheetId);
          await prefs.setString('mosque_sheet_$mosqueName', spreadsheetId);

          // Check if we should use direct service for recovery
          final usingDirectSheets = _isAdvancedSetup;
          await prefs.setBool('using_direct_sheets', usingDirectSheets);

          if (usingDirectSheets) {
            if (_selectedServiceAccountPath == null) {
              throw Exception('Please select a service account JSON file');
            }

            await prefs.setString(
                'service_account_path', _selectedServiceAccountPath!);

            final apiKey = _apiKeyController.text.trim();
            if (apiKey.isEmpty) {
              throw Exception('Please enter your Google Cloud API key');
            }
            await prefs.setString('google_api_key', apiKey);

            // Create direct service
            _directSheetsService = DirectGoogleSheetsService();
            await _directSheetsService!
                .initialize(_selectedServiceAccountPath!, apiKey);

            // Restore using direct service
            await _directSheetsService!.restoreFromRecoveryData(
              spreadsheetId,
              securityKey,
              DatabaseService.instance,
            );
          } else {
            // Use script-based recovery
            await _recoveryService.restoreFromRecoveryData(
                spreadsheetId, securityKey);
          }

          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Data recovered Successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        // This is a new setup (not recovery)
        // Check if we need to create a new spreadsheet ID
        if (spreadsheetId.isEmpty) {
          _logger.info(
              'No spreadsheet ID found, creating one automatically for new setup');

          try {
            if (_isAdvancedSetup) {
              // Advanced setup with direct Google Sheets API
              if (_selectedServiceAccountPath == null) {
                throw Exception('Please select a service account JSON file');
              }

              final email = _emailController.text.trim();
              if (email.isEmpty) {
                throw Exception('Please enter your email address for sharing');
              }

              final apiKey = _apiKeyController.text.trim();
              if (apiKey.isEmpty) {
                throw Exception('Please enter your Google Cloud API key');
              }

              // Create direct service
              _directSheetsService = DirectGoogleSheetsService();
              await _directSheetsService!
                  .initialize(_selectedServiceAccountPath!, apiKey);

              // Create spreadsheet with direct service
              _logger.info(
                  'Creating new spreadsheet using direct service for: $mosqueName');
              String newSpreadsheetId =
                  await _directSheetsService!.createNewSpreadsheet(
                mosqueName,
                [email], // Share with user's email
              );

              // Validate spreadsheet ID doesn't contain underscores
              if (newSpreadsheetId.contains('_')) {
                throw Exception(
                    'Generated spreadsheet ID contains underscores. Please try the setup again.');
              }

              // Set the spreadsheet ID to use
              spreadsheetId = newSpreadsheetId;

              // Create recovery data with direct service
              await _directSheetsService!.createRecoveryData(
                spreadsheetId,
                securityKey,
                DatabaseService.instance,
              );
            } else {
              // Standard setup with script-based service
              _logger.info('Creating new spreadsheet for: $mosqueName');
              String newSpreadsheetId =
                  await _recoveryService.createNewMosqueSpreadsheet(mosqueName);

              // Validate spreadsheet ID doesn't contain underscores
              if (newSpreadsheetId.contains('_')) {
                throw Exception(
                    'Generated spreadsheet ID contains underscores. Please try the setup again.');
              }

              // Set the spreadsheet ID to use
              spreadsheetId = newSpreadsheetId;

              // Create recovery data with script service
              await _recoveryService.createRecoveryData(
                  spreadsheetId, securityKey);
            }

            _logger.info('Created new spreadsheet ID: $spreadsheetId');

            // Show success message
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Cloud database created successfully!'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          } catch (e) {
            _logger.severe('Error creating spreadsheet automatically', e);
            throw Exception(
                'Failed to create cloud database automatically: ${e.toString()}');
          }
        }

        // Save the spreadsheet ID
        await prefs.setString('mosque_code', spreadsheetId);
        await prefs.setString('mosque_sheet_$mosqueName', spreadsheetId);

        // Save advanced setup preference
        if (_isAdvancedSetup) {
          await prefs.setBool('using_direct_sheets', true);
          if (_selectedServiceAccountPath != null) {
            await prefs.setString(
                'service_account_path', _selectedServiceAccountPath!);
          }
          if (_emailController.text.isNotEmpty) {
            await prefs.setString(
                'sheets_user_email', _emailController.text.trim());
          }
        } else {
          await prefs.setBool('using_direct_sheets', false);
        }
      }

      await prefs.setBool('first_launch', false);

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const ManagerMainScreen(),
        ),
      );
    } catch (e, stackTrace) {
      _logger.severe('Error saving data', e, stackTrace);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving data: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).primaryColor.withOpacity(0.1),
              Colors.white,
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),
                Icon(
                  Icons.mosque,
                  size: 80,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Welcome to Mosque Ease',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  _isRecoveryMode
                      ? 'Recover your existing mosque data'
                      : 'Set up your new Mosque Management System',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildModeButton(
                      icon: Icons.add_circle_outline,
                      label: 'New Setup',
                      isSelected: !_isRecoveryMode,
                      onPressed: _isLoading ? null : _handleNewSetup,
                    ),
                    _buildModeButton(
                      icon: Icons.restore,
                      label: 'Recover Data',
                      isSelected: _isRecoveryMode,
                      onPressed: _isLoading ? null : _handleRecovery,
                    ),
                  ],
                ),
                if (_isRecoveryMode) ...[
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildRecoveryTypeButton(
                        icon: Icons.cloud_outlined,
                        label: 'Cloud Recovery',
                        isSelected: !_isOfflineRecovery,
                        onPressed: _isLoading ? null : _handleRecovery,
                      ),
                      _buildRecoveryTypeButton(
                        icon: Icons.file_present_outlined,
                        label: 'Offline Backup',
                        isSelected: _isOfflineRecovery,
                        onPressed: _isLoading ? null : _handleOfflineRecovery,
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 40),
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      _buildTextField(
                        controller: _mosqueNameController,
                        label: 'Mosque Name',
                        icon: Icons.mosque,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter your Mosque name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      _buildTextField(
                        controller: _securityKeyController,
                        label: 'Security Key',
                        icon: Icons.lock,
                        showInfoIcon: true,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter a security key';
                          }
                          if (value.trim().length < 6) {
                            return 'Security key must be at least 6 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      if (_isRecoveryMode && !_isOfflineRecovery)
                        _buildTextField(
                          controller: _spreadsheetIdController,
                          label: 'Spreadsheet ID',
                          icon: Icons.table_chart,
                          validator: (value) {
                            if (_isRecoveryMode &&
                                !_isOfflineRecovery &&
                                (value == null || value.trim().isEmpty)) {
                              return 'Please enter your Secure key for recovery';
                            }
                            return null;
                          },
                        ),
                      if (_isRecoveryMode && _isOfflineRecovery) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.file_present,
                                    color: Theme.of(context).primaryColor,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _selectedBackupPath != null
                                          ? 'Selected Backup File:'
                                          : 'No Backup File Selected',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (_selectedBackupPath != null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  _selectedBackupPath!,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: _isLoading
                                      ? null
                                      : _searchAndPickBackupFile,
                                  icon: const Icon(Icons.upload_file),
                                  label: Text(_selectedBackupPath != null
                                      ? 'Change Backup File'
                                      : 'Select Backup File'),
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Advanced Setup Toggle
                      if (!_isOfflineRecovery) ...[
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: _isAdvancedSetup
                                ? Theme.of(context)
                                    .primaryColor
                                    .withOpacity(0.05)
                                : Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _isAdvancedSetup
                                  ? Theme.of(context)
                                      .primaryColor
                                      .withOpacity(0.3)
                                  : Colors.grey[300]!,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.settings,
                                    color: _isAdvancedSetup
                                        ? Theme.of(context).primaryColor
                                        : Colors.grey[600],
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Advanced Setup',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const Spacer(),
                                  Switch(
                                    value: _isAdvancedSetup,
                                    onChanged: _isLoading
                                        ? null
                                        : (value) {
                                            setState(() {
                                              _isAdvancedSetup = value;
                                            });
                                          },
                                    activeColor: Theme.of(context).primaryColor,
                                  ),
                                ],
                              ),
                              if (_isAdvancedSetup) ...[
                                const SizedBox(height: 8),
                                const Text(
                                  'Use your own Google service account for direct API access',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 16),

                                // Service Account File Picker
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border:
                                        Border.all(color: Colors.grey[300]!),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.insert_drive_file,
                                            color:
                                                Theme.of(context).primaryColor,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              _selectedServiceAccountPath !=
                                                      null
                                                  ? 'Service Account JSON File:'
                                                  : 'No Service Account File Selected',
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.help_outline,
                                                size: 18),
                                            onPressed: () =>
                                                _showServiceAccountHelpDialog(
                                                    context),
                                            tooltip:
                                                'Help with service account files',
                                          ),
                                        ],
                                      ),
                                      if (_selectedServiceAccountPath !=
                                          null) ...[
                                        const SizedBox(height: 6),
                                        Text(
                                          _selectedServiceAccountPath!,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                      const SizedBox(height: 12),
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton.icon(
                                          onPressed: _isLoading
                                              ? null
                                              : _pickServiceAccountFile,
                                          icon: const Icon(Icons.upload_file,
                                              size: 18),
                                          label: Text(
                                            _selectedServiceAccountPath != null
                                                ? 'Change Service Account File'
                                                : 'Select Service Account File',
                                            style:
                                                const TextStyle(fontSize: 14),
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 10),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(height: 16),

                                // Email for sharing
                                _buildTextField(
                                  controller: _emailController,
                                  label: 'Your Email Address',
                                  icon: Icons.email,
                                  validator: _isAdvancedSetup
                                      ? (value) {
                                          if (value == null ||
                                              value.trim().isEmpty) {
                                            return 'Please enter your email address';
                                          }
                                          if (!RegExp(
                                                  r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                                              .hasMatch(value)) {
                                            return 'Please enter a valid email address';
                                          }
                                          return null;
                                        }
                                      : null,
                                ),

                                const SizedBox(height: 12),
                                Text(
                                  'The spreadsheet will be shared with this email address',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),

                                const SizedBox(height: 16),

                                // API Key field
                                _buildTextField(
                                  controller: _apiKeyController,
                                  label: 'Google Cloud API Key',
                                  icon: Icons.vpn_key,
                                  validator: _isAdvancedSetup
                                      ? (value) {
                                          if (value == null ||
                                              value.trim().isEmpty) {
                                            return 'Please enter your Google Cloud API key';
                                          }
                                          return null;
                                        }
                                      : null,
                                ),

                                const SizedBox(height: 12),
                                Text(
                                  'API key from your Google Cloud project',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 40),
                      if (!_isRecoveryMode)
                        _buildActionButton(
                          onPressed: _isLoading ? null : _handleSendData,
                          label: 'Enable Cloud Database',
                          icon: Icons.cloud_upload,
                        ),
                      const SizedBox(height: 16),
                      _buildActionButton(
                        onPressed: _isLoading ? null : _handleSave,
                        label: _isRecoveryMode ? 'Recover Data' : 'Get Started',
                        icon: _isRecoveryMode
                            ? Icons.restore
                            : Icons.arrow_forward,
                        isPrimary: true,
                      ),
                    ],
                  ),
                ),
                if (_isLoading)
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(
                      child: CircularProgressIndicator(),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModeButton({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      width: 150,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor:
              isSelected ? Theme.of(context).primaryColor : Colors.grey[200],
          foregroundColor: isSelected ? Colors.white : Colors.black87,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecoveryTypeButton({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      width: 150,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: isSelected
              ? Theme.of(context).primaryColor.withOpacity(0.1)
              : Colors.transparent,
          foregroundColor: Theme.of(context).primaryColor,
          padding: const EdgeInsets.symmetric(vertical: 12),
          side: BorderSide(
            color:
                isSelected ? Theme.of(context).primaryColor : Colors.grey[400]!,
            width: isSelected ? 2 : 1,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 24,
                color: isSelected
                    ? Theme.of(context).primaryColor
                    : Colors.grey[600]),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: isSelected
                    ? Theme.of(context).primaryColor
                    : Colors.grey[600],
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String? Function(String?)? validator,
    bool showInfoIcon = false,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        suffixIcon: showInfoIcon
            ? IconButton(
                icon: const Icon(Icons.info_outline),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('About Security Key'),
                      content: const Text(
                        'The Security Key is used to protect your mosque data and enable secure data recovery. '
                        'Please keep this key safe as it will be required to restore your data in case of device loss or app reinstallation. '
                        'The key must be at least 6 characters long.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Got it'),
                        ),
                      ],
                    ),
                  );
                },
              )
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Theme.of(context).primaryColor),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
      validator: validator,
    );
  }

  Widget _buildActionButton({
    required VoidCallback? onPressed,
    required String label,
    required IconData icon,
    bool isPrimary = false,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor:
              isPrimary ? Theme.of(context).primaryColor : Colors.grey[200],
          foregroundColor: isPrimary ? Colors.white : Colors.black87,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  // Create a sample backup file for testing purposes
  Future<String?> _createSampleBackupFile() async {
    try {
      setState(() => _isLoading = true);
      _logger.info('Creating sample backup file');

      // Create sample data
      final sampleData = {
        'mosque_name': 'Test Mosque',
        'security_key': 'test123',
        'timestamp': DateTime.now().toIso8601String(),
        'report_header': 'Test Mosque Monthly Report',
        'payers': [
          {'id': 1, 'name': 'Test User 1'},
          {'id': 2, 'name': 'Test User 2'},
          {'id': 3, 'name': 'Test User 3'},
        ],
        'categories': [
          {'id': 1, 'name': 'Electricity'},
          {'id': 2, 'name': 'Water'},
          {'id': 3, 'name': 'Maintenance'},
        ],
        'transactions': [
          {
            'id': 1,
            'payer_id': 1,
            'amount': 100.0,
            'type': 'TransactionType.income',
            'category': 'Donation',
            'date': DateTime.now()
                .subtract(const Duration(days: 5))
                .toIso8601String(),
          },
          {
            'id': 2,
            'payer_id': 2,
            'amount': 200.0,
            'type': 'TransactionType.income',
            'category': 'Donation',
            'date': DateTime.now()
                .subtract(const Duration(days: 3))
                .toIso8601String(),
          },
          {
            'id': 3,
            'payer_id': 0,
            'amount': 50.0,
            'type': 'TransactionType.deduction',
            'category': 'Electricity',
            'date': DateTime.now()
                .subtract(const Duration(days: 1))
                .toIso8601String(),
          },
        ],
      };

      String filePath = '';
      String successMessage = '';
      bool savedToDownload = false;

      // Save to app documents directory first - this should work without special permissions
      try {
        final appDocDir = await getApplicationDocumentsDirectory();
        final appFile = File('${appDocDir.path}/mosque_backup_sample.json');
        await appFile.writeAsString(json.encode(sampleData));
        _logger.info('Sample file saved to app directory: ${appFile.path}');
        filePath = appFile.path;
        successMessage =
            'Sample backup file created in app directory: ${appFile.path}';
      } catch (e) {
        _logger.warning('Could not save to app documents directory: $e');
      }

      // Try to save to Downloads/Mosque_Fund directory as well, but handle gracefully if it fails
      try {
        final status = await Permission.storage.status;
        if (status.isGranted) {
          final downloadsDir = Directory('/storage/emulated/0/Download');
          if (await downloadsDir.exists()) {
            // Create Mosque_Fund directory if it doesn't exist
            final mosqueFundDir = Directory('${downloadsDir.path}/Mosque_Fund');
            if (!await mosqueFundDir.exists()) {
              await mosqueFundDir.create();
            }

            final publicFile =
                File('${mosqueFundDir.path}/mosque_backup_sample.json');
            await publicFile.writeAsString(json.encode(sampleData));
            _logger.info('Sample file saved to Downloads: ${publicFile.path}');

            if (filePath.isEmpty) {
              filePath = publicFile.path;
            }

            successMessage =
                'Sample backup file created at: ${publicFile.path}';
            savedToDownload = true;
          }
        } else {
          _logger.info(
              'Storage permission not granted, skipping external storage save');
        }
      } catch (e) {
        _logger.warning('Could not save to Downloads/Mosque_Fund: $e');
      }

      setState(() => _isLoading = false);

      // Show success message
      if (mounted && filePath.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(successMessage),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
          ),
        );

        if (!savedToDownload) {
          // Show a note about permissions if we couldn't save to Downloads
          await showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Sample Backup Created'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Sample backup created at: $filePath'),
                  const SizedBox(height: 12),
                  const Text(
                    'Note: The file could only be saved in the app\'s internal storage due to permission restrictions. This file will be deleted if the app is uninstalled.',
                    style: TextStyle(color: Colors.orange),
                  ),
                ],
              ),
              actions: [
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      }

      return filePath.isNotEmpty ? filePath : null;
    } catch (e, stackTrace) {
      setState(() => _isLoading = false);
      _logger.severe('Error creating sample backup file', e, stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating sample backup: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
      return null;
    }
  }

  void _showServiceAccountHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.info_outline, color: Theme.of(context).primaryColor),
            const SizedBox(width: 10),
            const Text('Service Account Files'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'A service account JSON file is required for direct API access to Google Sheets.',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text('How to identify a valid service account file:'),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('• File extension: .json'),
                    Text('• Contains: "type": "service_account"'),
                    Text('• Contains: "project_id": "your-project-id"'),
                    Text(
                        '• Contains: "private_key": "-----BEGIN PRIVATE KEY-----..."'),
                    Text(
                        '• Contains: "client_email": "something@your-project.iam.gserviceaccount.com"'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text('How to create a service account file:'),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('1. Go to the Google Cloud Console'),
                    Text('2. Create a new project or select existing one'),
                    Text('3. Navigate to "APIs & Services" > "Credentials"'),
                    Text('4. Click "Create Credentials" > "Service Account"'),
                    Text('5. Fill in the service account details'),
                    Text('6. Grant the account "Editor" permissions'),
                    Text('7. Click "Create Key", select JSON format'),
                    Text('8. The JSON file will be downloaded automatically'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'If you\'re having trouble selecting a JSON file, try these solutions:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                  '• Move the file to an accessible location like Downloads'),
              const Text(
                  '• Rename the file to clearly indicate it\'s a JSON file (e.g., service-account.json)'),
              const Text(
                  '• If selecting any file type, verify it has the correct format mentioned above'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}
