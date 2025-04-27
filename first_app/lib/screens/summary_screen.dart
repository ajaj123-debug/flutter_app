import 'package:flutter/material.dart';
import '../models/transaction.dart';
import '../services/database_service.dart';
import 'package:intl/intl.dart';
import '../widgets/translated_text.dart';
import '../services/language_service.dart';

class SummaryScreen extends StatefulWidget {
  const SummaryScreen({Key? key}) : super(key: key);

  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen> {
  final _database = DatabaseService.instance;
  final _currencyFormat = NumberFormat.currency(
    symbol: '₹',
    decimalDigits: 1,
    locale: 'en_IN',
  );

  final _languageService = LanguageService.instance;

  // Format currency according to language direction
  String _formatCurrency(double amount) {
    if (_languageService.currentLanguage == 'ur') {
      // For Urdu, manually format to ensure ₹ is before the amount
      final numberFormat = NumberFormat("#,##0.0", 'en_IN');
      return '₹ ${numberFormat.format(amount)}';
    } else {
      // For other languages, use the default formatting
      return _currencyFormat.format(amount);
    }
  }

  double _totalIncome = 0;
  double _totalSavings = 0;
  double _currentMonthSavings = 0;
  double _previousMonthSavings = 0;
  double _currentMonthIncome = 0;
  double _totalDeductions = 0;
  double _currentMonthDeductions = 0;
  List<Transaction> _currentMonthTransactions = [];
  List<Transaction> _recentDeductions = [];
  Map<int, String> _payerNames = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final now = DateTime.now();
    final firstDayOfMonth = DateTime(now.year, now.month, 1);
    final firstDayOfPrevMonth = DateTime(now.year, now.month - 1, 1);

    final transactions = await _database.getAllTransactions();
    final payers = await _database.getAllPayers();

    final payerNames = {for (var p in payers) p.id!: p.name};

    final currentMonthTransactions = transactions
        .where((t) =>
            t.date.isAfter(firstDayOfMonth) ||
            t.date.isAtSameMomentAs(firstDayOfMonth))
        .toList();

    final prevMonthTransactions = transactions
        .where((t) =>
            t.date.isAfter(firstDayOfPrevMonth) &&
            t.date.isBefore(firstDayOfMonth))
        .toList();

    if (!mounted) return;

    setState(() {
      _payerNames = payerNames;
      _totalIncome = _calculateTotal(transactions, TransactionType.income);
      _totalDeductions =
          _calculateTotal(transactions, TransactionType.deduction);
      _totalSavings = _totalIncome - _totalDeductions;

      _currentMonthIncome =
          _calculateTotal(currentMonthTransactions, TransactionType.income);
      _currentMonthDeductions =
          _calculateTotal(currentMonthTransactions, TransactionType.deduction);
      _currentMonthSavings = _currentMonthIncome - _currentMonthDeductions;

      _previousMonthSavings =
          _calculateTotal(prevMonthTransactions, TransactionType.income) -
              _calculateTotal(prevMonthTransactions, TransactionType.deduction);

      _currentMonthTransactions = currentMonthTransactions;
      _recentDeductions = transactions
          .where((t) => t.type == TransactionType.deduction)
          .take(7)
          .toList();
    });
  }

  double _calculateTotal(List<Transaction> transactions, TransactionType type) {
    return transactions
        .where((t) => t.type == type)
        .fold(0, (sum, t) => sum + t.amount);
  }

  Widget _buildGradientCard({
    required String title,
    required String amount,
    required List<Color> gradientColors,
    String? subtitle,
    IconData? icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: gradientColors.last.withOpacity(0.4),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TranslatedText(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (icon != null)
                Icon(icon, color: Colors.white.withOpacity(0.8), size: 24),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            amount,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 14,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTransactionList() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TranslatedText(
                  'recent_transactions',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                Text(
                  DateFormat('MMMM yyyy').format(DateTime.now()),
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _currentMonthTransactions.length,
            itemBuilder: (context, index) {
              final tx = _currentMonthTransactions[index];
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.grey.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: tx.type == TransactionType.deduction
                            ? Colors.red.withOpacity(0.1)
                            : Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        tx.type == TransactionType.deduction
                            ? Icons.arrow_downward
                            : Icons.arrow_upward,
                        color: tx.type == TransactionType.deduction
                            ? Colors.red
                            : Colors.green,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tx.type == TransactionType.income
                                ? (_payerNames[tx.payerId] ??
                                    'unknown_payer'.tr)
                                : tx.category,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            DateFormat('dd MMM yyyy').format(tx.date),
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      _formatCurrency(tx.amount),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: tx.type == TransactionType.income
                            ? Colors.green
                            : Colors.red,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDeductionsList() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TranslatedText(
                  'recent_deductions',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _formatCurrency(_currentMonthDeductions),
                    style: const TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _recentDeductions.length,
            itemBuilder: (context, index) {
              final tx = _recentDeductions[index];
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.grey.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        tx.category[0].toUpperCase(),
                        style: TextStyle(
                          color: Colors.grey[800],
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tx.category,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            DateFormat('dd MMM yyyy').format(tx.date),
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      _formatCurrency(tx.amount),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildGradientCard(
                title: 'total_balance',
                amount: _formatCurrency(_totalSavings),
                gradientColors: [Colors.blue, Colors.blue.shade800],
                subtitle:
                    '${'total_income'.tr}: ${_formatCurrency(_totalIncome)}',
                icon: Icons.account_balance_wallet,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildGradientCard(
                      title: 'this_month',
                      amount: _formatCurrency(_currentMonthSavings),
                      gradientColors: [Colors.green, Colors.green.shade800],
                      icon: Icons.trending_up,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildGradientCard(
                      title: 'last_month',
                      amount: _formatCurrency(_previousMonthSavings),
                      gradientColors: [Colors.orange, Colors.deepOrange],
                      icon: Icons.history,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildTransactionList(),
              const SizedBox(height: 24),
              _buildDeductionsList(),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
