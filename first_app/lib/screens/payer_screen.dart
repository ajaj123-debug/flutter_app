import 'package:flutter/material.dart';
import '../models/payer.dart';
import '../services/database_service.dart';
import '../services/language_service.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

class PayerScreen extends StatefulWidget {
  const PayerScreen({Key? key}) : super(key: key);

  @override
  State<PayerScreen> createState() => _PayerScreenState();
}

class _PayerScreenState extends State<PayerScreen> {
  final _database = DatabaseService.instance;
  final _formKey = GlobalKey<FormState>();
  final _payerNameController = TextEditingController();
  final _languageService = LanguageService.instance;
  List<Payer> _payers = [];
  bool _isLoading = false;
  StreamSubscription<String>? _languageChangeSubscription;
  String _currentUrduFont = 'NotoNastaliqUrdu'; // Default Urdu font

  @override
  void initState() {
    super.initState();
    _loadPayers();
    _loadSelectedUrduFont();

    // Subscribe to language changes
    _languageChangeSubscription =
        _languageService.onLanguageChanged.listen((_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  Future<void> _loadSelectedUrduFont() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedFont = prefs.getString('urdu_font');
      if (mounted) {
        setState(() {
          _currentUrduFont = savedFont ?? 'NotoNastaliqUrdu';
        });
      }
    } catch (e) {
      // Use default font on error
    }
  }

  TextStyle _getUrduAwareTextStyle(TextStyle baseStyle) {
    // Apply custom font only if language is Urdu
    if (_languageService.currentLanguage == 'ur') {
      return baseStyle.copyWith(
        fontFamily: _currentUrduFont,
        height: 1.5, // Add some line height for better readability
      );
    }
    return baseStyle;
  }

  @override
  void dispose() {
    _payerNameController.dispose();
    _languageChangeSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadPayers() async {
    setState(() => _isLoading = true);
    final payers = await _database.getAllPayers();
    setState(() {
      _payers = payers;
      _isLoading = false;
    });
  }

  Future<void> _addPayer() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() => _isLoading = true);
      try {
        final payer = await _database.createPayer(
          Payer(name: _payerNameController.text.trim()),
        );
        _payerNameController.clear();
        await _loadPayers();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _languageService.t('payer_added_successfully') ??
                    'Payer added Successfully',
                style: _getUrduAwareTextStyle(const TextStyle()),
              ),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _languageService.t('error_unique_payer_name') ??
                    'Payer name must be unique',
                style: _getUrduAwareTextStyle(const TextStyle()),
              ),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deletePayer(Payer payer) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            _languageService.t('delete_payer') ?? 'Delete Payer',
            style: _getUrduAwareTextStyle(const TextStyle()),
          ),
          content: Text(
            (_languageService.t('confirm_delete_payer') ??
                    'Are you sure you want to delete "{name}"?')
                .replaceAll('{name}', payer.name),
            style: _getUrduAwareTextStyle(const TextStyle()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                _languageService.t('cancel') ?? 'Cancel',
                style: _getUrduAwareTextStyle(const TextStyle()),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: Text(
                _languageService.t('delete') ?? 'Delete',
                style: _getUrduAwareTextStyle(const TextStyle()),
              ),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        await _database.deletePayer(payer.id!);
        await _loadPayers();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _languageService.t('payer_deleted_successfully') ??
                    'Payer deleted Successfully',
                style: _getUrduAwareTextStyle(const TextStyle()),
              ),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _languageService.t('error_deleting_payer') ??
                    'Error deleting payer',
                style: _getUrduAwareTextStyle(const TextStyle()),
              ),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _languageService.t('manage_payers') ?? 'Payers',
          style: _getUrduAwareTextStyle(const TextStyle()),
        ),
        backgroundColor: Colors.green,
        elevation: 0,
      ),
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.green.withOpacity(0.1),
                  Colors.white,
                ],
              ),
            ),
          ),
          // Main content
          Column(
            children: [
              // Add Payer Form
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      spreadRadius: 1,
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: _payerNameController,
                        decoration: InputDecoration(
                          labelText: _languageService.t('enter_payer_name') ??
                              'Enter Payer Name',
                          labelStyle: _getUrduAwareTextStyle(TextStyle(
                            color: Colors.grey[700],
                          )),
                          prefixIcon: const Icon(Icons.person_outline,
                              color: Colors.green),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Colors.grey.withOpacity(0.3),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Colors.green,
                              width: 2,
                            ),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return _languageService
                                    .t('please_enter_payer_name') ??
                                'Please enter a payer name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _addPayer,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                _languageService.t('add_payer') ?? 'ADD PAYER',
                                style: _getUrduAwareTextStyle(const TextStyle(
                                  fontWeight: FontWeight.bold,
                                )),
                              ),
                      ),
                    ],
                  ),
                ),
              ),

              // Payers List Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  children: [
                    const Icon(
                      Icons.people_outline,
                      color: Colors.green,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _languageService.t('payers_list') ?? 'Payers List',
                      style: _getUrduAwareTextStyle(const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      )),
                    ),
                    const Spacer(),
                    Text(
                      (_languageService.t('items_count') ?? '{count} items')
                          .replaceAll('{count}', _payers.length.toString()),
                      style: _getUrduAwareTextStyle(TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      )),
                    ),
                  ],
                ),
              ),

              // Payers List
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Colors.green,
                        ),
                      )
                    : _payers.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.people_outline,
                                  size: 64,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _languageService.t('no_payers_yet') ??
                                      'No payers yet',
                                  style: _getUrduAwareTextStyle(TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 16,
                                  )),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _languageService
                                          .t('add_payer_to_get_started') ??
                                      'Add a new payer to get started',
                                  style: _getUrduAwareTextStyle(TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 14,
                                  )),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _payers.length,
                            itemBuilder: (context, index) {
                              final payer = _payers[index];
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.grey.withOpacity(0.1),
                                      spreadRadius: 1,
                                      blurRadius: 5,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  leading: Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: Colors.green.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Center(
                                      child: Text(
                                        '${index + 1}',
                                        style: const TextStyle(
                                          color: Colors.green,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    payer.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  trailing: IconButton(
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      color: Colors.green,
                                    ),
                                    onPressed: () => _deletePayer(payer),
                                  ),
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
