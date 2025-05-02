import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart';
import '../services/database_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'dart:io';
import 'package:flutter/services.dart';
import 'tabular_transaction_history_screen.dart';
import '../widgets/translated_text.dart';
import '../services/language_service.dart';
import '../services/ad_service.dart';
import 'package:logging/logging.dart' as logging;

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({Key? key}) : super(key: key);

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen>
    with SingleTickerProviderStateMixin {
  final DatabaseService _database = DatabaseService.instance;
  final LanguageService _languageService = LanguageService.instance;
  static final _logger = logging.Logger('ReportsScreen');
  late NumberFormat _currencyFormat;
  String _currencySymbol = '₹'; // Default currency
  bool _hasSelectedCurrency = false;
  late pw.Font _pdfFont;
  bool _isAdLoading = false;

  // Scroll controller for button text animations
  final Map<String, ScrollController> _scrollControllers = {};
  // Scroll physics - initially disabled for auto-scrolling, then enabled for manual
  ScrollPhysics _scrollPhysics = const NeverScrollableScrollPhysics();

  final List<Map<String, String>> _currencies = [
    {'symbol': '₹', 'name': 'Indian Rupee'},
    {'symbol': 'SAR', 'name': 'Saudi Riyal'},
    {'symbol': 'AFN', 'name': 'Afghan Afghani'},
    {'symbol': '৳', 'name': 'Bangladeshi Taka'},
    {'symbol': 'रु', 'name': 'Nepalese Rupee'},
    {'symbol': '₨', 'name': 'Pakistani Rupee'},
  ];

  DateTime _selectedDate = DateTime.now();
  List<Transaction> _transactions = [];
  List<Transaction> _deductions = [];
  double _totalIncome = 0;
  double _totalDeductions = 0;
  double _totalSavings = 0;
  Map<int, String> _payerNames = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _currencyFormat = NumberFormat.currency(
      symbol: _currencySymbol,
      decimalDigits: 1,
      locale: 'en_IN',
    );
    _loadFont();
    _loadCurrency();
    _loadData();

    // Initialize and preload rewarded ads
    _initializeAds();
  }

  // Initialize and preload ads
  Future<void> _initializeAds() async {
    try {
      final adService = AdService();
      await adService.initialize();
      await adService.loadRewardedAd();
    } catch (e) {
      _logger.warning('Error initializing ads: $e');
    }
  }

  // Check if ad needs to be shown for a specific feature
  Future<bool> _checkAndShowAdIfNeeded(String featureKey) async {
    final prefs = await SharedPreferences.getInstance();
    final today =
        DateTime.now().toString().substring(0, 10); // YYYY-MM-DD format
    final lastAdWatchDate = prefs.getString('report_ad_watch_date_$featureKey');
    final adAlreadyWatchedToday = lastAdWatchDate == today;

    // If ad already watched today for this specific feature, return true to continue
    if (adAlreadyWatchedToday) {
      _logger.info('Ad already watched today for $featureKey, proceeding');
      return true;
    }

    // Map feature keys to user-friendly names
    final featureNames = {
      'view_pdf': 'View PDF Report',
      'save_pdf': 'Save PDF Report',
      'analysis': 'Reports Analysis',
      'share': 'Share Report'
    };

    final featureName = featureNames[featureKey] ?? 'this feature';

    // Check if a rewarded ad is available
    final adService = AdService();
    if (adService.isRewardedAdReady()) {
      // Show dialog explaining ad requirement
      if (!mounted) return false;

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: Text('Watch an Ad for $featureName'),
          content: Text(
            'You need to watch a short ad to use $featureName. After watching the ad, you can use this feature without ads for the rest of the day.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );

      setState(() {
        _isAdLoading = true;
      });

      // Show rewarded ad
      final bool rewardEarned = await adService.showRewardedAd(context);

      setState(() {
        _isAdLoading = false;
      });

      if (rewardEarned) {
        _logger.info('User earned reward from $featureKey ad, continuing');
        // Save the date when ad was watched specifically for this feature
        await prefs.setString('report_ad_watch_date_$featureKey', today);
        return true;
      } else {
        _logger
            .info('User did not earn reward from $featureKey ad, cancelling');
        if (!mounted) return false;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Please watch the ad completely to use $featureName'),
            backgroundColor: Colors.orange,
          ),
        );
        return false;
      }
    } else {
      // No ad available, preload for next time and allow this time
      adService.loadRewardedAd();
      _logger.info('No ad available for $featureKey, proceeding anyway');
      return true;
    }
  }

  // Modified to check for ad before proceeding - for View PDF
  Future<void> _handleViewPDFAction() async {
    // First check currency selection
    if (!_hasSelectedCurrency) {
      await _showCurrencySelectionDialog();
      if (!_hasSelectedCurrency) return; // User cancelled currency selection
    }

    // Check if ad needs to be shown for View PDF specifically
    final canProceed = await _checkAndShowAdIfNeeded('view_pdf');
    if (!canProceed) return;

    // Proceed with action
    await _generatePDFReport();
  }

  // Modified to check for ad before proceeding - for Save PDF
  Future<void> _handleSavePDFAction() async {
    // First check currency selection
    if (!_hasSelectedCurrency) {
      await _showCurrencySelectionDialog();
      if (!_hasSelectedCurrency) return; // User cancelled currency selection
    }

    // Check if ad needs to be shown for Save PDF specifically
    final canProceed = await _checkAndShowAdIfNeeded('save_pdf');
    if (!canProceed) return;

    // Proceed with action
    await _savePDFToDownloads();
  }

  // Modified to check for ad before proceeding
  Future<void> _showCopyOptionsDialog() async {
    // Check if ad needs to be shown for Share specifically
    final canProceed = await _checkAndShowAdIfNeeded('share');
    if (!canProceed) return;

    final bool? result = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        bool copyFullReport = false;
        bool copyNonPayers = false;

        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              elevation: 0,
              backgroundColor: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      spreadRadius: 1,
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header with icon
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF25D366).withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.share,
                        color: Color(0xFF25D366),
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Title
                    const TranslatedText(
                      'share_report',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const TranslatedText(
                      'select_what_to_share',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Options
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.grey[200]!,
                        ),
                      ),
                      child: Column(
                        children: [
                          CheckboxListTile(
                            title: const TranslatedText(
                              'full_report',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: Colors.black87,
                              ),
                            ),
                            subtitle: const TranslatedText(
                              'full_report_description',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                              ),
                            ),
                            value: copyFullReport,
                            onChanged: (bool? value) {
                              setState(() {
                                copyFullReport = value ?? false;
                              });
                            },
                            activeColor: const Color(0xFF25D366),
                            controlAffinity: ListTileControlAffinity.leading,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                          ),
                          Divider(
                            height: 1,
                            color: Colors.grey[200],
                            indent: 16,
                          ),
                          CheckboxListTile(
                            title: const TranslatedText(
                              'non_payers_list',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: Colors.black87,
                              ),
                            ),
                            subtitle: const TranslatedText(
                              'non_payers_description',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                              ),
                            ),
                            value: copyNonPayers,
                            onChanged: (bool? value) {
                              setState(() {
                                copyNonPayers = value ?? false;
                              });
                            },
                            activeColor: const Color(0xFF25D366),
                            controlAffinity: ListTileControlAffinity.leading,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Buttons
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const TranslatedText(
                              'cancel',
                              style: TextStyle(
                                color: Colors.black54,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              if (copyFullReport || copyNonPayers) {
                                Navigator.pop(context, true);
                                _copyTransactionsToClipboard(
                                    copyFullReport, copyNonPayers);
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                        'Please select at least one option'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF25D366),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const TranslatedText(
                              'share',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _copyTransactionsToClipboard(
      bool copyFullReport, bool copyNonPayers) async {
    final monthName = DateFormat('MMMM').format(_selectedDate);
    final year = _selectedDate.year;
    final month = _selectedDate.month;

    // Define the custom order for payers
    final orderedNames = [
      'अब्बास अली',
      'Abbas Ali',
      'अबास अली',
      'Abas Ali',
      'मुमताज अली',
      'Mumtaj Ali',
      'Mumtaz Ali',
      'मुमताज़ अली',
      'नासिर अली',
      'Nasir Ali',
      'नासीर अली',
      'एहसान अली',
      'Ahsan Ali',
      'Ehsan Ali'
    ];

    // Get all payers and identify defaulters
    final allPayers = await _database.getAllPayers();
    final payingPayerIds = _transactions.map((t) => t.payerId).toSet();
    final nonPayingPayers = allPayers
        .where((p) => !payingPayerIds.contains(p.id))
        .map((p) => p.name)
        .toList();

    // Sort non-paying payers
    nonPayingPayers.sort((a, b) {
      final indexA = orderedNames.indexOf(a);
      final indexB = orderedNames.indexOf(b);
      if (indexA != -1 && indexB != -1) {
        return indexA.compareTo(indexB);
      } else if (indexA != -1) {
        return -1;
      } else if (indexB != -1) {
        return 1;
      } else {
        return a.compareTo(b);
      }
    });

    // Sort transactions
    _transactions.sort((a, b) {
      final payerA = _payerNames[a.payerId] ?? '';
      final payerB = _payerNames[b.payerId] ?? '';
      final indexA = orderedNames.indexOf(payerA);
      final indexB = orderedNames.indexOf(payerB);
      if (indexA != -1 && indexB != -1) {
        return indexA.compareTo(indexB);
      } else if (indexA != -1) {
        return -1;
      } else if (indexB != -1) {
        return 1;
      } else {
        return payerA.compareTo(payerB);
      }
    });

    final buffer = StringBuffer();

    if (copyFullReport) {
      final monthName = DateFormat('MMMM').format(_selectedDate);
      final year = _selectedDate.year.toString();

      buffer.writeln(_languageService
          .translate('monthly_report_title')
          .replaceAll('{month}', monthName)
          .replaceAll('{year}', year));
      buffer.writeln('${_languageService.translate('income_section')}:\n');

      for (var i = 0; i < _transactions.length; i++) {
        final transaction = _transactions[i];
        final payerName = _payerNames[transaction.payerId] ??
            _languageService.translate('unknown_payer');
        buffer.writeln(
            '${i + 1}. $payerName   ➨   $_currencySymbol${transaction.amount}');
      }

      buffer.writeln('\n${_languageService.translate('expense_section')}:');
      for (var i = 0; i < _deductions.length; i++) {
        final deduction = _deductions[i];
        final formattedDate = DateFormat('MM/dd/yy').format(deduction.date);
        buffer.writeln(
            '${i + 1}. ${deduction.category} ➨ $_currencySymbol${deduction.amount} ➨ $formattedDate');
      }

      buffer.writeln('\n${_languageService.translate('summary_section')}:');
      buffer.writeln(
          '\n${_languageService.translate('income_emoji')}: $_currencySymbol$_totalIncome');
      buffer.writeln(
          '${_languageService.translate('expense_emoji')}: $_currencySymbol$_totalDeductions');
      buffer.writeln(
          '${_languageService.translate('savings_emoji')}: $_currencySymbol$_totalSavings\n');
    }

    if (copyNonPayers && nonPayingPayers.isNotEmpty) {
      final monthName = DateFormat('MMMM').format(_selectedDate);
      buffer.writeln(
          '\n${_languageService.translate('pending_payment_request').replaceAll('{month}', monthName)}\n');
      for (var i = 0; i < nonPayingPayers.length; i++) {
        buffer.write('${i + 1}. ${nonPayingPayers[i]}');
        if (i < nonPayingPayers.length - 1) {
          buffer.writeln();
        }
      }
    }

    await Clipboard.setData(ClipboardData(text: buffer.toString()));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_languageService.translate('transactions_copied')),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  // New handler for analysis screen that checks for ad
  Future<void> _openAnalysisScreen() async {
    // Check if ad needs to be shown for Analysis specifically
    final canProceed = await _checkAndShowAdIfNeeded('analysis');
    if (!canProceed) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const TabularTransactionHistoryScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Date Selection Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TranslatedText(
                            'select_month',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          Text(
                            _languageService
                                .translate('currency_label')
                                .replaceAll('{symbol}', _currencySymbol),
                            style: TextStyle(
                              color: Theme.of(context).primaryColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () => _selectDate(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                DateFormat('MMMM yyyy').format(_selectedDate),
                                style: const TextStyle(fontSize: 16),
                              ),
                              const Icon(Icons.calendar_today),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Summary Cards
              Row(
                children: [
                  Expanded(
                    child: _buildSummaryCard(
                      'total_income',
                      _currencyFormat.format(_totalIncome),
                      Colors.green,
                      Icons.arrow_upward,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildSummaryCard(
                      'total_deductions',
                      _currencyFormat.format(_totalDeductions),
                      Colors.red,
                      Icons.arrow_downward,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildSummaryCard(
                'total_savings',
                _currencyFormat.format(_totalSavings),
                Colors.blue,
                Icons.account_balance,
              ),
              const SizedBox(height: 24),

              // Generate Report Buttons
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // First row of buttons
                      Row(
                        children: [
                          Expanded(
                            child: _buildActionButton(
                              context,
                              'view_pdf',
                              Icons.picture_as_pdf,
                              Theme.of(context).primaryColor,
                              _isLoading || _isAdLoading
                                  ? null
                                  : _handleViewPDFAction,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildActionButton(
                              context,
                              'save_pdf',
                              Icons.download,
                              Colors.green,
                              _isLoading || _isAdLoading
                                  ? null
                                  : _handleSavePDFAction,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Second row of buttons
                      Row(
                        children: [
                          Expanded(
                            child: _buildActionButton(
                              context,
                              'view_reports_analysis',
                              Icons.analytics,
                              Colors.blue,
                              _isLoading || _isAdLoading
                                  ? null
                                  : _openAnalysisScreen,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildActionButton(
                              context,
                              'share_report',
                              Icons.share,
                              const Color(0xFF25D366),
                              _isLoading || _isAdLoading
                                  ? null
                                  : _showCopyOptionsDialog,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Information about where reports are saved
              Card(
                color: Colors.blue.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.blue.shade700),
                          const SizedBox(width: 8),
                          TranslatedText(
                            'report_information',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const TranslatedText(
                        'report_information_description',
                        style: TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_isLoading || _isAdLoading)
          Container(
            color: Colors.black.withOpacity(0.3),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  if (_isAdLoading)
                    const Padding(
                      padding: EdgeInsets.only(top: 16.0),
                      child: Text(
                        'Loading Ad...',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSummaryCard(
      String title, String amount, Color color, IconData icon) {
    return InkWell(
      onTap: () {
        if (title == 'total_income') {
          _showTransactionsDialog(TransactionType.income);
        } else if (title == 'total_deductions') {
          _showTransactionsDialog(TransactionType.deduction);
        }
      },
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: color, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TranslatedText(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                amount,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Method to show transactions in a dialog
  Future<void> _showTransactionsDialog(TransactionType type) async {
    // Filter transactions of the selected type
    final filteredTransactions =
        type == TransactionType.income ? _transactions : _deductions;

    String typeText;
    if (type == TransactionType.income) {
      typeText =
          'Income Transactions'; // Using direct string instead of translation for now
    } else {
      typeText =
          'Expense Transactions'; // Using direct string instead of translation for now
    }

    // Sort transactions by date - most recent first
    filteredTransactions.sort((a, b) => b.date.compareTo(a.date));

    if (!mounted) return;

    final monthYear = DateFormat('MMM yyyy').format(_selectedDate);

    await showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            padding: const EdgeInsets.all(16),
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.7,
              maxWidth: MediaQuery.of(context).size.width * 0.9,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: Colors.grey.shade200,
                        width: 1.0,
                      ),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Icon(
                            type == TransactionType.income
                                ? Icons.arrow_upward
                                : Icons.arrow_downward,
                            color: type == TransactionType.income
                                ? Colors.green
                                : Colors.red,
                          ),
                          Expanded(
                            child: Text(
                              typeText,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(context),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        monthYear,
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: filteredTransactions.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.inbox_outlined,
                                size: 48,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No transactions found',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          itemCount: filteredTransactions.length,
                          separatorBuilder: (context, index) =>
                              const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final transaction = filteredTransactions[index];
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 8.0,
                                vertical: 2.0,
                              ),
                              leading: CircleAvatar(
                                backgroundColor: type == TransactionType.income
                                    ? Colors.green.shade100
                                    : Colors.red.shade100,
                                child: Icon(
                                  type == TransactionType.income
                                      ? Icons.arrow_upward
                                      : Icons.arrow_downward,
                                  color: type == TransactionType.income
                                      ? Colors.green
                                      : Colors.red,
                                  size: 20,
                                ),
                              ),
                              title: type == TransactionType.income
                                  ? Text(
                                      _payerNames[transaction.payerId] ??
                                          'Unknown',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w500),
                                    )
                                  : Text(
                                      transaction.category,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w500),
                                    ),
                              subtitle: Text(
                                DateFormat('dd MMM yyyy')
                                    .format(transaction.date),
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey.shade600),
                              ),
                              trailing: Text(
                                _currencyFormat.format(transaction.amount),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: type == TransactionType.income
                                      ? Colors.green
                                      : Colors.red,
                                ),
                              ),
                            );
                          },
                        ),
                ),

                // Footer with totals
                if (filteredTransactions.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.only(top: 12),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: Colors.grey.shade200,
                          width: 1.0,
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.grey.shade800,
                          ),
                        ),
                        Text(
                          _currencyFormat.format(filteredTransactions.fold(0.0,
                              (sum, transaction) => sum + transaction.amount)),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: type == TransactionType.income
                                ? Colors.green
                                : Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionButton(
    BuildContext context,
    String label,
    IconData icon,
    Color color,
    VoidCallback? onPressed,
  ) {
    // Only create and manage scroll controller for the Analysis button
    if (label == 'view_reports_analysis') {
      if (!_scrollControllers.containsKey(label)) {
        _scrollControllers[label] = ScrollController();
      }
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withOpacity(0.8),
            color,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            spreadRadius: 1,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: label == 'view_reports_analysis'
                  ? SingleChildScrollView(
                      controller: _scrollControllers[label],
                      scrollDirection: Axis.horizontal,
                      physics: _scrollPhysics,
                      child: TranslatedText(
                        label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    )
                  : TranslatedText(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Start auto-scrolling after the widget is built and has dependencies
    if (_scrollControllers.containsKey('view_reports_analysis')) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _startAutoScroll('view_reports_analysis');
        }
      });
    }
  }

  // Add missing methods that were referenced in our implementation
  Future<void> _loadFont() async {
    final fontData = await rootBundle.load('assets/fonts/NotoSans-Regular.ttf');
    _pdfFont = pw.Font.ttf(fontData);
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final transactions = await _database.getAllTransactions();
    final payers = await _database.getAllPayers();

    final payerNames = {
      for (var p in payers)
        if (p.id != null) p.id!: p.name
    };

    final currentMonthTransactions = transactions
        .where((t) =>
            t.date.year == _selectedDate.year &&
            t.date.month == _selectedDate.month)
        .toList();

    setState(() {
      _payerNames = payerNames;
      _transactions = currentMonthTransactions
          .where((t) => t.type == TransactionType.income)
          .toList();
      _deductions = currentMonthTransactions
          .where((t) => t.type == TransactionType.deduction)
          .toList();
      _totalIncome = _transactions.fold(0, (sum, t) => sum + t.amount);
      _totalDeductions = _deductions.fold(0, (sum, t) => sum + t.amount);
      _totalSavings = _totalIncome - _totalDeductions;
      _isLoading = false;
    });
  }

  Future<void> _loadCurrency() async {
    final prefs = await SharedPreferences.getInstance();
    final currencySymbol = prefs.getString('currency_symbol') ?? '₹';
    final hasSelected = prefs.getBool('has_selected_currency') ?? false;
    setState(() {
      _currencySymbol = currencySymbol;
      _hasSelectedCurrency = hasSelected;
      _currencyFormat = NumberFormat.currency(
        symbol: _currencySymbol,
        decimalDigits: 1,
        locale: 'en_IN',
      );
    });
  }

  Future<void> _showCurrencySelectionDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Select Currency'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _currencies.length,
            itemBuilder: (context, index) {
              final currency = _currencies[index];
              return ListTile(
                leading: Text(
                  currency['symbol']!,
                  style: const TextStyle(fontSize: 20),
                ),
                title: Text(currency['name']!),
                onTap: () async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString('currency_symbol', currency['symbol']!);
                  await prefs.setBool('has_selected_currency', true);
                  setState(() {
                    _currencySymbol = currency['symbol']!;
                    _hasSelectedCurrency = true;
                    _currencyFormat = NumberFormat.currency(
                      symbol: _currencySymbol,
                      decimalDigits: 1,
                      locale: 'en_IN',
                    );
                  });
                  Navigator.pop(context);
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).primaryColor,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (date != null) {
      setState(() {
        _selectedDate = date;
      });
      _loadData();
    }
  }

  // Helper function to determine appropriate margins based on background image
  pw.EdgeInsets _getMarginForBackground(String? backgroundImage) {
    if (backgroundImage == null) {
      return const pw.EdgeInsets.all(30); // Default margins
    }

    // Different margins for different background images
    if (backgroundImage.contains('report_background_image_1.jpg')) {
      return const pw.EdgeInsets.all(
          75); // Islamic pattern with decorative border
    } else if (backgroundImage.contains('report_background_image_2.jpg')) {
      return const pw.EdgeInsets.fromLTRB(
          60, 50, 60, 50); // Adjust based on the actual image
    } else if (backgroundImage.contains('report_background_image_3.jpg')) {
      return const pw.EdgeInsets.fromLTRB(
          86, 92, 86, 92); // Adjust based on the actual image
    } else if (backgroundImage.contains('report_background_image_4.jpg')) {
      return const pw.EdgeInsets.fromLTRB(
          86, 92, 86, 92); // Adjust based on the actual image
    }

    // Default for any other backgrounds
    return const pw.EdgeInsets.all(30);
  }

  // Helper function to get appropriate colors for each background
  pw.ThemeData _getThemeForBackground(String? backgroundImage) {
    // Default theme with black text
    final defaultTheme = pw.ThemeData.withFont(
      base: _pdfFont,
      bold: _pdfFont,
      italic: _pdfFont,
      boldItalic: _pdfFont,
    );

    if (backgroundImage == null) {
      return defaultTheme;
    }

    // Customized themes based on background images
    if (backgroundImage.contains('report_background_image_1.jpg')) {
      // Islamic pattern - using default black text
      return defaultTheme;
    } else if (backgroundImage.contains('report_background_image_2.jpg')) {
      // Custom colors that match background 2
      return pw.ThemeData.withFont(
        base: _pdfFont,
        bold: _pdfFont,
        italic: _pdfFont,
        boldItalic: _pdfFont,
      ).copyWith(
        // Customize text colors to match the background
        defaultTextStyle: const pw.TextStyle(
          color: PdfColors.indigo900,
          fontSize: 12,
        ),
        paragraphStyle: const pw.TextStyle(
          color: PdfColors.indigo900,
          fontSize: 12,
        ),
        header0: pw.TextStyle(
          color: PdfColors.indigo800,
          fontSize: 20,
          fontWeight: pw.FontWeight.bold,
        ),
        header1: pw.TextStyle(
          color: PdfColors.indigo800,
          fontSize: 16,
          fontWeight: pw.FontWeight.bold,
        ),
      );
    } else if (backgroundImage.contains('report_background_image_3.jpg')) {
      // Custom colors that match background 3
      return pw.ThemeData.withFont(
        base: _pdfFont,
        bold: _pdfFont,
        italic: _pdfFont,
        boldItalic: _pdfFont,
      ).copyWith(
        // Customize text colors to match the background
        defaultTextStyle: const pw.TextStyle(
          color: PdfColors.teal900,
          fontSize: 12,
        ),
        paragraphStyle: const pw.TextStyle(
          color: PdfColors.teal900,
          fontSize: 12,
        ),
        header0: pw.TextStyle(
          color: PdfColors.teal800,
          fontSize: 20,
          fontWeight: pw.FontWeight.bold,
        ),
        header1: pw.TextStyle(
          color: PdfColors.teal800,
          fontSize: 16,
          fontWeight: pw.FontWeight.bold,
        ),
      );
    } else if (backgroundImage.contains('report_background_image_4.jpg')) {
      // Custom colors that match background 4
      return pw.ThemeData.withFont(
        base: _pdfFont,
        bold: _pdfFont,
        italic: _pdfFont,
        boldItalic: _pdfFont,
      ).copyWith(
        // Customize text colors to match the background
        defaultTextStyle: const pw.TextStyle(
          color: PdfColors.teal500,
          fontSize: 12,
        ),
        paragraphStyle: const pw.TextStyle(
          color: PdfColors.teal500,
          fontSize: 12,
        ),
        header0: pw.TextStyle(
          color: PdfColors.teal800,
          fontSize: 20,
          fontWeight: pw.FontWeight.bold,
        ),
        header1: pw.TextStyle(
          color: PdfColors.teal800,
          fontSize: 16,
          fontWeight: pw.FontWeight.bold,
        ),
      );
    }

    // Default theme for any other backgrounds
    return defaultTheme;
  }

  Future<void> _generatePDFReport() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final mosqueName = prefs.getString('masjid_name');
      final backgroundImage = prefs.getString('report_background_image');

      if (mosqueName == null || mosqueName.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please complete mosque setup first'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Create PDF document
      final pdf = pw.Document();

      // Get all payers and identify defaulters
      final allPayers = await _database.getAllPayers();
      final payingPayerIds = _transactions.map((t) => t.payerId).toSet();
      final nonPayingPayers = allPayers
          .where((p) => !payingPayerIds.contains(p.id))
          .map((p) => p.name)
          .toList();

      // Load background image if selected
      pw.Image? backgroundPwImage;
      if (backgroundImage != null) {
        try {
          final bgBytes =
              await rootBundle.load('assets/images/$backgroundImage');
          final bgImage = pw.MemoryImage(bgBytes.buffer.asUint8List());
          backgroundPwImage = pw.Image(bgImage, fit: pw.BoxFit.fill);
        } catch (e) {
          _logger.warning('Error loading background image: $e');
        }
      }

      // Add page to PDF
      pdf.addPage(
        pw.MultiPage(
          pageTheme: pw.PageTheme(
            pageFormat: PdfPageFormat.a4,
            buildBackground:
                backgroundImage != null && backgroundPwImage != null
                    ? (pw.Context context) {
                        return pw.FullPage(
                          ignoreMargins: true,
                          child: backgroundPwImage!,
                        );
                      }
                    : null,
            // Use helper function to get appropriate margins
            margin: _getMarginForBackground(backgroundImage),
            theme: _getThemeForBackground(backgroundImage),
          ),
          build: (pw.Context context) {
            return [
              // Header
              pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 10),
                child: pw.Text(
                  '$mosqueName - Monthly Report',
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                    font: _pdfFont,
                    color: _getTextColorForBackground(backgroundImage),
                  ),
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Text(
                DateFormat('MMMM yyyy').format(_selectedDate),
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  font: _pdfFont,
                ),
              ),
              pw.SizedBox(height: 20),

              // Income Section
              pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 10),
                child: pw.Text(
                  'Income Transactions',
                  style: pw.TextStyle(
                    font: _pdfFont,
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: _getTextColorForBackground(backgroundImage),
                  ),
                ),
              ),
              pw.SizedBox(height: 5),
              pw.Table(
                border: pw.TableBorder(
                  left: pw.BorderSide(
                      color: _getTextColorForBackground(backgroundImage)),
                  top: pw.BorderSide(
                      color: _getTextColorForBackground(backgroundImage)),
                  right: pw.BorderSide(
                      color: _getTextColorForBackground(backgroundImage)),
                  bottom: pw.BorderSide(
                      color: _getTextColorForBackground(backgroundImage)),
                  horizontalInside: pw.BorderSide(
                      color: _getTextColorForBackground(backgroundImage)),
                  verticalInside: pw.BorderSide(
                      color: _getTextColorForBackground(backgroundImage)),
                ),
                children: [
                  // Table header
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text('S.No.',
                            style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                font: _pdfFont,
                                color: _getTextColorForBackground(
                                    backgroundImage))),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text('Payer Name',
                            style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                font: _pdfFont,
                                color: _getTextColorForBackground(
                                    backgroundImage))),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text('Amount',
                            style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                font: _pdfFont,
                                color: _getTextColorForBackground(
                                    backgroundImage))),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text('Date',
                            style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                font: _pdfFont,
                                color: _getTextColorForBackground(
                                    backgroundImage))),
                      ),
                    ],
                  ),
                  // Table rows
                  ..._transactions.asMap().entries.map((entry) => pw.TableRow(
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(5),
                            child: pw.Text('${entry.key + 1}',
                                style: pw.TextStyle(
                                  font: _pdfFont,
                                  color: _getTextColorForBackground(
                                      backgroundImage),
                                )),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(5),
                            child: pw.Text(
                              _payerNames[entry.value.payerId] ?? 'Unknown',
                              style: pw.TextStyle(
                                font: _pdfFont,
                                color:
                                    _getTextColorForBackground(backgroundImage),
                              ),
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(5),
                            child: pw.Text(
                              _currencyFormat.format(entry.value.amount),
                              style: pw.TextStyle(
                                font: _pdfFont,
                                color:
                                    _getTextColorForBackground(backgroundImage),
                              ),
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(5),
                            child: pw.Text(
                              DateFormat('dd/MM/yyyy').format(entry.value.date),
                              style: pw.TextStyle(
                                font: _pdfFont,
                                color:
                                    _getTextColorForBackground(backgroundImage),
                              ),
                            ),
                          ),
                        ],
                      )),
                ],
              ),
              pw.SizedBox(height: 20),

              // Deductions Section
              pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 10),
                child: pw.Text(
                  'Deductions',
                  style: pw.TextStyle(
                    font: _pdfFont,
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: _getTextColorForBackground(backgroundImage),
                  ),
                ),
              ),
              pw.SizedBox(height: 5),
              pw.Table(
                border: pw.TableBorder(
                  left: pw.BorderSide(
                      color: _getTextColorForBackground(backgroundImage)),
                  top: pw.BorderSide(
                      color: _getTextColorForBackground(backgroundImage)),
                  right: pw.BorderSide(
                      color: _getTextColorForBackground(backgroundImage)),
                  bottom: pw.BorderSide(
                      color: _getTextColorForBackground(backgroundImage)),
                  horizontalInside: pw.BorderSide(
                      color: _getTextColorForBackground(backgroundImage)),
                  verticalInside: pw.BorderSide(
                      color: _getTextColorForBackground(backgroundImage)),
                ),
                children: [
                  // Table header
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text('S.No.',
                            style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                font: _pdfFont,
                                color: _getTextColorForBackground(
                                    backgroundImage))),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text('Category',
                            style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                font: _pdfFont,
                                color: _getTextColorForBackground(
                                    backgroundImage))),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text('Amount',
                            style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                font: _pdfFont,
                                color: _getTextColorForBackground(
                                    backgroundImage))),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text('Date',
                            style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                font: _pdfFont,
                                color: _getTextColorForBackground(
                                    backgroundImage))),
                      ),
                    ],
                  ),
                  // Table rows for deductions
                  ..._deductions.asMap().entries.map((entry) => pw.TableRow(
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(5),
                            child: pw.Text('${entry.key + 1}',
                                style: pw.TextStyle(
                                  font: _pdfFont,
                                  color: _getTextColorForBackground(
                                      backgroundImage),
                                )),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(5),
                            child: pw.Text(entry.value.category,
                                style: pw.TextStyle(
                                  font: _pdfFont,
                                  color: _getTextColorForBackground(
                                      backgroundImage),
                                )),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(5),
                            child: pw.Text(
                              _currencyFormat.format(entry.value.amount),
                              style: pw.TextStyle(
                                font: _pdfFont,
                                color:
                                    _getTextColorForBackground(backgroundImage),
                              ),
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(5),
                            child: pw.Text(
                              DateFormat('dd/MM/yyyy').format(entry.value.date),
                              style: pw.TextStyle(
                                font: _pdfFont,
                                color:
                                    _getTextColorForBackground(backgroundImage),
                              ),
                            ),
                          ),
                        ],
                      )),
                ],
              ),
              pw.SizedBox(height: 20),

              // Summary Section
              pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 10),
                child: pw.Text(
                  'Summary',
                  style: pw.TextStyle(
                    font: _pdfFont,
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: _getTextColorForBackground(backgroundImage),
                  ),
                ),
              ),
              pw.SizedBox(height: 5),
              pw.Table(
                border: pw.TableBorder(
                  left: pw.BorderSide(
                      color: _getTextColorForBackground(backgroundImage)),
                  top: pw.BorderSide(
                      color: _getTextColorForBackground(backgroundImage)),
                  right: pw.BorderSide(
                      color: _getTextColorForBackground(backgroundImage)),
                  bottom: pw.BorderSide(
                      color: _getTextColorForBackground(backgroundImage)),
                  horizontalInside: pw.BorderSide(
                      color: _getTextColorForBackground(backgroundImage)),
                  verticalInside: pw.BorderSide(
                      color: _getTextColorForBackground(backgroundImage)),
                ),
                children: [
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text('Total Income',
                            style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                font: _pdfFont,
                                color: _getTextColorForBackground(
                                    backgroundImage))),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text(_currencyFormat.format(_totalIncome),
                            style: pw.TextStyle(
                                font: _pdfFont,
                                color: _getTextColorForBackground(
                                    backgroundImage))),
                      ),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text('Total Deductions',
                            style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                font: _pdfFont,
                                color: _getTextColorForBackground(
                                    backgroundImage))),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text(_currencyFormat.format(_totalDeductions),
                            style: pw.TextStyle(
                                font: _pdfFont,
                                color: _getTextColorForBackground(
                                    backgroundImage))),
                      ),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text('Total Savings',
                            style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                font: _pdfFont,
                                color: _getTextColorForBackground(
                                    backgroundImage))),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text(_currencyFormat.format(_totalSavings),
                            style: pw.TextStyle(
                                font: _pdfFont,
                                color: _getTextColorForBackground(
                                    backgroundImage))),
                      ),
                    ],
                  ),
                ],
              ),

              // Non-paying Payers Section
              pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 10),
                child: pw.Text(
                  'Pending Payments',
                  style: pw.TextStyle(
                    font: _pdfFont,
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: _getTextColorForBackground(backgroundImage),
                  ),
                ),
              ),
              pw.SizedBox(height: 5),
              pw.Table(
                border: pw.TableBorder(
                  left: pw.BorderSide(
                      color: _getTextColorForBackground(backgroundImage)),
                  top: pw.BorderSide(
                      color: _getTextColorForBackground(backgroundImage)),
                  right: pw.BorderSide(
                      color: _getTextColorForBackground(backgroundImage)),
                  bottom: pw.BorderSide(
                      color: _getTextColorForBackground(backgroundImage)),
                  horizontalInside: pw.BorderSide(
                      color: _getTextColorForBackground(backgroundImage)),
                  verticalInside: pw.BorderSide(
                      color: _getTextColorForBackground(backgroundImage)),
                ),
                children: [
                  // Table header
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text('S.No.',
                            style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                font: _pdfFont,
                                color: _getTextColorForBackground(
                                    backgroundImage))),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text('Payer Name',
                            style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                font: _pdfFont,
                                color: _getTextColorForBackground(
                                    backgroundImage))),
                      ),
                    ],
                  ),
                  // Get all payers and identify defaulters
                  ...List.generate(
                      nonPayingPayers.length,
                      (index) => pw.TableRow(
                            children: [
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(5),
                                child: pw.Text('${index + 1}',
                                    style: pw.TextStyle(
                                      font: _pdfFont,
                                      color: _getTextColorForBackground(
                                          backgroundImage),
                                    )),
                              ),
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(5),
                                child: pw.Text(nonPayingPayers[index],
                                    style: pw.TextStyle(
                                      font: _pdfFont,
                                      color: _getTextColorForBackground(
                                          backgroundImage),
                                    )),
                              ),
                            ],
                          )),
                ],
              ),

              // Add MosqueEase branding footer with custom divider
              pw.SizedBox(height: 40),
              pw.Container(
                height: 0.5,
                color: PdfColors.grey400,
                margin: const pw.EdgeInsets.symmetric(horizontal: 20),
              ),
              pw.SizedBox(height: 10),
              pw.Text(
                "MosqueEase",
                style: pw.TextStyle(
                  color: PdfColors.blue900,
                  fontWeight: pw.FontWeight.bold,
                  font: _pdfFont,
                  fontSize: 14,
                ),
                textAlign: pw.TextAlign.center,
              ),
              pw.SizedBox(height: 8),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text(
                    "Report generated by MosqueEase App",
                    style: pw.TextStyle(
                      font: _pdfFont,
                      color: PdfColors.grey800,
                      fontSize: 10,
                    ),
                    textAlign: pw.TextAlign.center,
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    "Simplifying Mosque Fund Management",
                    style: pw.TextStyle(
                      font: _pdfFont,
                      color: PdfColors.grey700,
                      fontSize: 9,
                      fontStyle: pw.FontStyle.italic,
                    ),
                    textAlign: pw.TextAlign.center,
                  ),
                  pw.SizedBox(height: 6),
                  pw.Text(
                    "Generated on: ${DateFormat('dd MMMM yyyy, hh:mm a').format(DateTime.now())}",
                    style: pw.TextStyle(
                      font: _pdfFont,
                      color: PdfColors.grey600,
                      fontSize: 8,
                    ),
                    textAlign: pw.TextAlign.center,
                  ),
                ],
              ),
            ];
          },
        ),
      );

      // Save the PDF to a temporary file
      final output = await getTemporaryDirectory();
      final file = File(
          '${output.path}/${mosqueName}_Monthly_Report_${DateFormat('MMM_yyyy').format(_selectedDate)}.pdf');
      await file.writeAsBytes(await pdf.save());

      // Open the PDF file
      await OpenFile.open(file.path);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('PDF report generated Successfully!'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'OK',
            textColor: Colors.white,
            onPressed: () {},
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error generating PDF report: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _initScrollControllers() {
    // Clear existing controllers
    for (var controller in _scrollControllers.values) {
      controller.dispose();
    }
    _scrollControllers.clear();

    // Initialize new controller for analysis button
    _scrollControllers['view_reports_analysis'] = ScrollController();
  }

  void _startAutoScroll(String key) {
    if (!_scrollControllers.containsKey(key) || !mounted) return;

    final controller = _scrollControllers[key]!;
    if (!controller.hasClients) return;

    // Only animate if the content is wider than the container
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (controller.position.maxScrollExtent > 0) {
        _animateScroll(controller, 2000);
      }
    });
  }

  void _animateScroll(ScrollController controller, int milliseconds) {
    if (!mounted) return;

    // Animate to the end
    controller
        .animateTo(
      controller.position.maxScrollExtent,
      duration: Duration(milliseconds: milliseconds),
      curve: Curves.easeInOut,
    )
        .then((_) {
      // Wait a moment at the end
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!mounted) return;

        // Animate back to the start
        controller
            .animateTo(
          0,
          duration: Duration(milliseconds: milliseconds),
          curve: Curves.easeInOut,
        )
            .then((_) {
          // Enable manual scrolling after one complete cycle
          if (mounted) {
            setState(() {
              _scrollPhysics = const ClampingScrollPhysics();
            });
          }
        });
      });
    });
  }

  Future<void> _savePDFToDownloads() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final mosqueName = prefs.getString('masjid_name');
      final backgroundImage = prefs.getString('report_background_image');

      if (mosqueName == null || mosqueName.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please complete mosque setup first'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Create PDF document
      final pdf = pw.Document();

      // Get all payers and identify defaulters
      final allPayers = await _database.getAllPayers();
      final payingPayerIds = _transactions.map((t) => t.payerId).toSet();
      final nonPayingPayers = allPayers
          .where((p) => !payingPayerIds.contains(p.id))
          .map((p) => p.name)
          .toList();

      // Load background image if selected
      pw.Image? backgroundPwImage;
      if (backgroundImage != null) {
        try {
          final bgBytes =
              await rootBundle.load('assets/images/$backgroundImage');
          final bgImage = pw.MemoryImage(bgBytes.buffer.asUint8List());
          backgroundPwImage = pw.Image(bgImage, fit: pw.BoxFit.fill);
        } catch (e) {
          _logger.warning('Error loading background image: $e');
        }
      }

      // Add page to PDF
      pdf.addPage(
        pw.MultiPage(
          pageTheme: pw.PageTheme(
            pageFormat: PdfPageFormat.a4,
            buildBackground:
                backgroundImage != null && backgroundPwImage != null
                    ? (pw.Context context) {
                        return pw.FullPage(
                          ignoreMargins: true,
                          child: backgroundPwImage!,
                        );
                      }
                    : null,
            // Use helper function to get appropriate margins
            margin: _getMarginForBackground(backgroundImage),
            theme: _getThemeForBackground(backgroundImage),
          ),
          build: (pw.Context context) {
            return [
              // Header
              pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 10),
                child: pw.Text(
                  '$mosqueName - Monthly Report',
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                    font: _pdfFont,
                    color: _getTextColorForBackground(backgroundImage),
                  ),
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Text(
                DateFormat('MMMM yyyy').format(_selectedDate),
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  font: _pdfFont,
                ),
              ),
              pw.SizedBox(height: 20),

              // Income Section
              pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 10),
                child: pw.Text(
                  'Income Transactions',
                  style: pw.TextStyle(
                    font: _pdfFont,
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: _getTextColorForBackground(backgroundImage),
                  ),
                ),
              ),
              pw.SizedBox(height: 5),
              pw.Table(
                border: pw.TableBorder(
                  left: pw.BorderSide(
                      color: _getTextColorForBackground(backgroundImage)),
                  top: pw.BorderSide(
                      color: _getTextColorForBackground(backgroundImage)),
                  right: pw.BorderSide(
                      color: _getTextColorForBackground(backgroundImage)),
                  bottom: pw.BorderSide(
                      color: _getTextColorForBackground(backgroundImage)),
                  horizontalInside: pw.BorderSide(
                      color: _getTextColorForBackground(backgroundImage)),
                  verticalInside: pw.BorderSide(
                      color: _getTextColorForBackground(backgroundImage)),
                ),
                children: [
                  // Table header
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text('S.No.',
                            style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                font: _pdfFont,
                                color: _getTextColorForBackground(
                                    backgroundImage))),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text('Payer Name',
                            style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                font: _pdfFont,
                                color: _getTextColorForBackground(
                                    backgroundImage))),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text('Amount',
                            style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                font: _pdfFont,
                                color: _getTextColorForBackground(
                                    backgroundImage))),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text('Date',
                            style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                font: _pdfFont,
                                color: _getTextColorForBackground(
                                    backgroundImage))),
                      ),
                    ],
                  ),
                  // Table rows
                  ..._transactions.asMap().entries.map((entry) => pw.TableRow(
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(5),
                            child: pw.Text('${entry.key + 1}',
                                style: pw.TextStyle(
                                  font: _pdfFont,
                                  color: _getTextColorForBackground(
                                      backgroundImage),
                                )),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(5),
                            child: pw.Text(
                              _payerNames[entry.value.payerId] ?? 'Unknown',
                              style: pw.TextStyle(
                                font: _pdfFont,
                                color:
                                    _getTextColorForBackground(backgroundImage),
                              ),
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(5),
                            child: pw.Text(
                              _currencyFormat.format(entry.value.amount),
                              style: pw.TextStyle(
                                font: _pdfFont,
                                color:
                                    _getTextColorForBackground(backgroundImage),
                              ),
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(5),
                            child: pw.Text(
                              DateFormat('dd/MM/yyyy').format(entry.value.date),
                              style: pw.TextStyle(
                                font: _pdfFont,
                                color:
                                    _getTextColorForBackground(backgroundImage),
                              ),
                            ),
                          ),
                        ],
                      )),
                ],
              ),
              pw.SizedBox(height: 20),

              // Deductions Section
              pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 10),
                child: pw.Text(
                  'Deductions',
                  style: pw.TextStyle(
                    font: _pdfFont,
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: _getTextColorForBackground(backgroundImage),
                  ),
                ),
              ),
              pw.SizedBox(height: 5),
              pw.Table(
                border: pw.TableBorder(
                  left: pw.BorderSide(
                      color: _getTextColorForBackground(backgroundImage)),
                  top: pw.BorderSide(
                      color: _getTextColorForBackground(backgroundImage)),
                  right: pw.BorderSide(
                      color: _getTextColorForBackground(backgroundImage)),
                  bottom: pw.BorderSide(
                      color: _getTextColorForBackground(backgroundImage)),
                  horizontalInside: pw.BorderSide(
                      color: _getTextColorForBackground(backgroundImage)),
                  verticalInside: pw.BorderSide(
                      color: _getTextColorForBackground(backgroundImage)),
                ),
                children: [
                  // Table header
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text('S.No.',
                            style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                font: _pdfFont,
                                color: _getTextColorForBackground(
                                    backgroundImage))),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text('Category',
                            style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                font: _pdfFont,
                                color: _getTextColorForBackground(
                                    backgroundImage))),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text('Amount',
                            style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                font: _pdfFont,
                                color: _getTextColorForBackground(
                                    backgroundImage))),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text('Date',
                            style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                font: _pdfFont,
                                color: _getTextColorForBackground(
                                    backgroundImage))),
                      ),
                    ],
                  ),
                  // Table rows for deductions
                  ..._deductions.asMap().entries.map((entry) => pw.TableRow(
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(5),
                            child: pw.Text('${entry.key + 1}',
                                style: pw.TextStyle(
                                  font: _pdfFont,
                                  color: _getTextColorForBackground(
                                      backgroundImage),
                                )),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(5),
                            child: pw.Text(entry.value.category,
                                style: pw.TextStyle(
                                  font: _pdfFont,
                                  color: _getTextColorForBackground(
                                      backgroundImage),
                                )),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(5),
                            child: pw.Text(
                              _currencyFormat.format(entry.value.amount),
                              style: pw.TextStyle(
                                font: _pdfFont,
                                color:
                                    _getTextColorForBackground(backgroundImage),
                              ),
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(5),
                            child: pw.Text(
                              DateFormat('dd/MM/yyyy').format(entry.value.date),
                              style: pw.TextStyle(
                                font: _pdfFont,
                                color:
                                    _getTextColorForBackground(backgroundImage),
                              ),
                            ),
                          ),
                        ],
                      )),
                ],
              ),
              pw.SizedBox(height: 20),

              // Summary Section
              pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 10),
                child: pw.Text(
                  'Summary',
                  style: pw.TextStyle(
                    font: _pdfFont,
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: _getTextColorForBackground(backgroundImage),
                  ),
                ),
              ),
              pw.SizedBox(height: 5),
              pw.Table(
                border: pw.TableBorder(
                  left: pw.BorderSide(
                      color: _getTextColorForBackground(backgroundImage)),
                  top: pw.BorderSide(
                      color: _getTextColorForBackground(backgroundImage)),
                  right: pw.BorderSide(
                      color: _getTextColorForBackground(backgroundImage)),
                  bottom: pw.BorderSide(
                      color: _getTextColorForBackground(backgroundImage)),
                  horizontalInside: pw.BorderSide(
                      color: _getTextColorForBackground(backgroundImage)),
                  verticalInside: pw.BorderSide(
                      color: _getTextColorForBackground(backgroundImage)),
                ),
                children: [
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text('Total Income',
                            style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                font: _pdfFont,
                                color: _getTextColorForBackground(
                                    backgroundImage))),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text(_currencyFormat.format(_totalIncome),
                            style: pw.TextStyle(
                                font: _pdfFont,
                                color: _getTextColorForBackground(
                                    backgroundImage))),
                      ),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text('Total Deductions',
                            style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                font: _pdfFont,
                                color: _getTextColorForBackground(
                                    backgroundImage))),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text(_currencyFormat.format(_totalDeductions),
                            style: pw.TextStyle(
                                font: _pdfFont,
                                color: _getTextColorForBackground(
                                    backgroundImage))),
                      ),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text('Total Savings',
                            style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                font: _pdfFont,
                                color: _getTextColorForBackground(
                                    backgroundImage))),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text(_currencyFormat.format(_totalSavings),
                            style: pw.TextStyle(
                                font: _pdfFont,
                                color: _getTextColorForBackground(
                                    backgroundImage))),
                      ),
                    ],
                  ),
                ],
              ),

              // Non-paying Payers Section
              pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 10),
                child: pw.Text(
                  'Pending Payments',
                  style: pw.TextStyle(
                    font: _pdfFont,
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: _getTextColorForBackground(backgroundImage),
                  ),
                ),
              ),
              pw.SizedBox(height: 5),
              pw.Table(
                border: pw.TableBorder(
                  left: pw.BorderSide(
                      color: _getTextColorForBackground(backgroundImage)),
                  top: pw.BorderSide(
                      color: _getTextColorForBackground(backgroundImage)),
                  right: pw.BorderSide(
                      color: _getTextColorForBackground(backgroundImage)),
                  bottom: pw.BorderSide(
                      color: _getTextColorForBackground(backgroundImage)),
                  horizontalInside: pw.BorderSide(
                      color: _getTextColorForBackground(backgroundImage)),
                  verticalInside: pw.BorderSide(
                      color: _getTextColorForBackground(backgroundImage)),
                ),
                children: [
                  // Table header
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text('S.No.',
                            style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                font: _pdfFont,
                                color: _getTextColorForBackground(
                                    backgroundImage))),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text('Payer Name',
                            style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                font: _pdfFont,
                                color: _getTextColorForBackground(
                                    backgroundImage))),
                      ),
                    ],
                  ),
                  // Get all payers and identify defaulters
                  ...List.generate(
                      nonPayingPayers.length,
                      (index) => pw.TableRow(
                            children: [
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(5),
                                child: pw.Text('${index + 1}',
                                    style: pw.TextStyle(
                                      font: _pdfFont,
                                      color: _getTextColorForBackground(
                                          backgroundImage),
                                    )),
                              ),
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(5),
                                child: pw.Text(nonPayingPayers[index],
                                    style: pw.TextStyle(
                                      font: _pdfFont,
                                      color: _getTextColorForBackground(
                                          backgroundImage),
                                    )),
                              ),
                            ],
                          )),
                ],
              ),

              // Add MosqueEase branding footer with custom divider
              pw.SizedBox(height: 40),
              pw.Container(
                height: 0.5,
                color: PdfColors.grey400,
                margin: const pw.EdgeInsets.symmetric(horizontal: 20),
              ),
              pw.SizedBox(height: 10),
              pw.Text(
                "MosqueEase",
                style: pw.TextStyle(
                  color: PdfColors.blue900,
                  fontWeight: pw.FontWeight.bold,
                  font: _pdfFont,
                  fontSize: 14,
                ),
                textAlign: pw.TextAlign.center,
              ),
              pw.SizedBox(height: 8),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text(
                    "Report generated by MosqueEase App",
                    style: pw.TextStyle(
                      font: _pdfFont,
                      color: PdfColors.grey800,
                      fontSize: 10,
                    ),
                    textAlign: pw.TextAlign.center,
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    "Simplifying Mosque Fund Management",
                    style: pw.TextStyle(
                      font: _pdfFont,
                      color: PdfColors.grey700,
                      fontSize: 9,
                      fontStyle: pw.FontStyle.italic,
                    ),
                    textAlign: pw.TextAlign.center,
                  ),
                  pw.SizedBox(height: 6),
                  pw.Text(
                    "Generated on: ${DateFormat('dd MMMM yyyy, hh:mm a').format(DateTime.now())}",
                    style: pw.TextStyle(
                      font: _pdfFont,
                      color: PdfColors.grey600,
                      fontSize: 8,
                    ),
                    textAlign: pw.TextAlign.center,
                  ),
                ],
              ),
            ];
          },
        ),
      );

      // Get the downloads directory and create a Mosque_Fund subfolder
      Directory? downloadsDir;
      if (Platform.isAndroid) {
        // For Android, use the downloads directory
        downloadsDir = Directory('/storage/emulated/0/Download');
        if (!await downloadsDir.exists()) {
          downloadsDir = await getExternalStorageDirectory();
        }
      } else {
        // For iOS, use the documents directory
        downloadsDir = await getApplicationDocumentsDirectory();
      }

      if (downloadsDir == null) {
        throw Exception('Could not access downloads directory');
      }

      // Create Mosque_Fund subfolder
      final mosqueFundDir = Directory('${downloadsDir.path}/Mosque_Fund');
      if (!await mosqueFundDir.exists()) {
        await mosqueFundDir.create(recursive: true);
      }

      // Create a unique filename with current timestamp
      final now = DateTime.now();
      final timestamp =
          "${now.year}_${now.month.toString().padLeft(2, '0')}_${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}";
      final fileName =
          '${mosqueName}_Monthly_Report_${DateFormat('MMM_yyyy').format(_selectedDate)}_$timestamp.pdf';

      final file = File('${mosqueFundDir.path}/$fileName');
      await file.writeAsBytes(await pdf.save());

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PDF report saved to: ${file.path}'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'OK',
            textColor: Colors.white,
            onPressed: () {},
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving PDF report: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Add a method to get the appropriate text color based on background
  PdfColor _getTextColorForBackground(String? backgroundImage) {
    if (backgroundImage == null) {
      return PdfColors.black; // Default text color
    }

    // Different text colors for different backgrounds
    if (backgroundImage.contains('report_background_image_1.jpg')) {
      return PdfColors.black;
    } else if (backgroundImage.contains('report_background_image_2.jpg')) {
      return PdfColors.indigo900;
    } else if (backgroundImage.contains('report_background_image_3.jpg')) {
      return PdfColors.teal900;
    } else if (backgroundImage.contains('report_background_image_4.jpg')) {
      return PdfColors
          .teal500; // Changed from brown to teal to match your updates
    }

    return PdfColors.black; // Default text color
  }
}
