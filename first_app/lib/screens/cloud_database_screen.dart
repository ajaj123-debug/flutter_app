import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CloudDatabaseScreen extends StatefulWidget {
  const CloudDatabaseScreen({Key? key}) : super(key: key);

  @override
  State<CloudDatabaseScreen> createState() => _CloudDatabaseScreenState();
}

class _CloudDatabaseScreenState extends State<CloudDatabaseScreen> {
  String? _mosqueName;
  String? _spreadsheetId;
  bool _isLoading = true;
  bool _usingDirectSheets = false;
  String? _serviceAccountPath;
  String? _sheetsUserEmail;
  String? _googleApiKey;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final mosqueName = prefs.getString('masjid_name');
      if (mosqueName != null) {
        final spreadsheetId = prefs.getString('mosque_sheet_$mosqueName');
        final usingDirectSheets = prefs.getBool('using_direct_sheets') ?? false;
        final serviceAccountPath = prefs.getString('service_account_path');
        final sheetsUserEmail = prefs.getString('sheets_user_email');
        final googleApiKey = prefs.getString('google_api_key');

        setState(() {
          _mosqueName = mosqueName;
          _spreadsheetId = spreadsheetId;
          _usingDirectSheets = usingDirectSheets;
          _serviceAccountPath = serviceAccountPath;
          _sheetsUserEmail = sheetsUserEmail;
          _googleApiKey = googleApiKey;
        });
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _copyToClipboard() async {
    if (_spreadsheetId != null) {
      await Clipboard.setData(ClipboardData(text: _spreadsheetId!));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Spreadsheet ID copied to clipboard'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _copyServiceAccountPath() async {
    if (_serviceAccountPath != null) {
      await Clipboard.setData(ClipboardData(text: _serviceAccountPath!));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Service account path copied to clipboard'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _copyApiKey() async {
    if (_googleApiKey != null) {
      await Clipboard.setData(ClipboardData(text: _googleApiKey!));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('API key copied to clipboard'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cloud Database Settings'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 12,
                            children: [
                              const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.cloud_outlined,
                                      color: Colors.blue),
                                  SizedBox(width: 12),
                                  Flexible(
                                    child: Text(
                                      'Cloud Database Integration',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (_usingDirectSheets)
                                Chip(
                                  label: const Text('Advanced'),
                                  backgroundColor: Colors.blue.withOpacity(0.1),
                                  labelStyle: const TextStyle(
                                    color: Colors.blue,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          if (_mosqueName != null) ...[
                            Text(
                              'Mosque Name:',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _mosqueName!,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],
                          Text(
                            'Secure Key:',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (_spreadsheetId != null) ...[
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _spreadsheetId!,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontFamily: 'monospace',
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.copy),
                                  onPressed: _copyToClipboard,
                                  tooltip: 'Copy to clipboard',
                                ),
                              ],
                            ),
                          ] else
                            const Text(
                              'No spreadsheet connected',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.red,
                              ),
                            ),
                          if (_usingDirectSheets &&
                              _serviceAccountPath != null) ...[
                            const SizedBox(height: 24),
                            const Divider(),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.settings, color: Colors.purple[700]),
                                const SizedBox(width: 12),
                                const Text(
                                  'Advanced Setup Details',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Service Account File:',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _serviceAccountPath!,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontFamily: 'monospace',
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.copy),
                                  onPressed: _copyServiceAccountPath,
                                  tooltip: 'Copy path to clipboard',
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            if (_sheetsUserEmail != null) ...[
                              Text(
                                'Shared With:',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.email,
                                      size: 16, color: Colors.grey),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      _sheetsUserEmail!,
                                      style: const TextStyle(
                                        fontSize: 16,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            if (_googleApiKey != null) ...[
                              const SizedBox(height: 16),
                              Text(
                                'API Key:',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${_googleApiKey!.substring(0, 4)}...${_googleApiKey!.substring(_googleApiKey!.length - 4)}',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.copy),
                                    onPressed: _copyApiKey,
                                    tooltip: 'Copy API key to clipboard',
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                            ],
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: Colors.orange.withOpacity(0.3)),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.info_outline,
                                      color: Colors.orange[700]),
                                  const SizedBox(width: 12),
                                  const Expanded(
                                    child: Text(
                                      'You are using your own Google service account for direct API access. Keep your service account file secure.',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'About Cloud Integration',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildInfoItem(
                            'Automatic Sync',
                            'Data is automatically synced Cloud Database',
                            Icons.sync,
                          ),
                          const SizedBox(height: 16),
                          _buildInfoItem(
                            'Secure Storage',
                            'Your data is securely stored in Cloud Database',
                            Icons.security,
                          ),
                          const SizedBox(height: 16),
                          _buildInfoItem(
                            'Easy Access',
                            'Access your data from any device with Secure Key ',
                            Icons.devices,
                          ),
                          if (_usingDirectSheets) ...[
                            const SizedBox(height: 16),
                            _buildInfoItem(
                              'Advanced Control',
                              'Direct API access with your own service account',
                              Icons.admin_panel_settings,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  if (_usingDirectSheets && _spreadsheetId != null) ...[
                    const SizedBox(height: 24),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.open_in_new,
                                    color: Colors.green[700]),
                                const SizedBox(width: 12),
                                const Text(
                                  'Direct Access',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'You can access your spreadsheet directly with this URL:',
                              style: TextStyle(fontSize: 16),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey[300]!),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'https://docs.google.com/spreadsheets/d/${_spreadsheetId!}/edit',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontFamily: 'monospace',
                                        color: Colors.blue,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.copy),
                                    onPressed: () async {
                                      final url =
                                          'https://docs.google.com/spreadsheets/d/${_spreadsheetId!}/edit';
                                      await Clipboard.setData(
                                          ClipboardData(text: url));
                                      if (!mounted) return;
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content:
                                              Text('URL copied to clipboard'),
                                          backgroundColor: Colors.green,
                                        ),
                                      );
                                    },
                                    tooltip: 'Copy URL to clipboard',
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildInfoItem(String title, String description, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: Theme.of(context).primaryColor,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                description,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
