import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart';
import '../services/database_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'monthly_amount_chart_screen.dart';
import 'package:linked_scroll_controller/linked_scroll_controller.dart';

class TabularTransactionHistoryScreen extends StatefulWidget {
  const TabularTransactionHistoryScreen({Key? key}) : super(key: key);

  @override
  State<TabularTransactionHistoryScreen> createState() =>
      _TabularTransactionHistoryScreenState();
}

class _TabularTransactionHistoryScreenState
    extends State<TabularTransactionHistoryScreen> {
  final DatabaseService _database = DatabaseService.instance;
  late NumberFormat _currencyFormat;
  String _currencySymbol = '₹';
  bool _hasSelectedCurrency = false;
  int _selectedYear = DateTime.now().year;
  List<int> _availableYears = [];
  List<String> _payers = [];
  List<List<bool>> _paymentStatus = [];
  bool _isLoading = true;
  String _searchQuery = '';

  // Linked scroll controller groups
  late LinkedScrollControllerGroup _verticalControllerGroup;
  late ScrollController _namesListController;
  late ScrollController _statusGridController;

  late LinkedScrollControllerGroup _horizontalControllerGroup;
  late ScrollController _monthHeaderController;
  late ScrollController _statusRowController;

  final List<String> _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec'
  ];

  @override
  void initState() {
    super.initState();

    // Initialize linked scroll controllers
    _verticalControllerGroup = LinkedScrollControllerGroup();
    _namesListController = _verticalControllerGroup.addAndGet();
    _statusGridController = _verticalControllerGroup.addAndGet();

    _horizontalControllerGroup = LinkedScrollControllerGroup();
    _monthHeaderController = _horizontalControllerGroup.addAndGet();
    _statusRowController = _horizontalControllerGroup.addAndGet();

    _loadCurrency();
    _loadData();
  }

  @override
  void dispose() {
    _namesListController.dispose();
    _statusGridController.dispose();
    _monthHeaderController.dispose();
    _statusRowController.dispose();
    super.dispose();
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

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final transactions = await _database.getAllTransactions();
      final years = transactions.map((t) => t.date.year).toSet().toList();
      years.sort((a, b) => b.compareTo(a));

      final payers = await _database.getAllPayers();
      final payerNames = payers.map((p) => p.name).toList();

      final paymentStatus = List.generate(
        payerNames.length,
        (i) => List.generate(12, (j) => false),
      );

      for (int i = 0; i < payerNames.length; i++) {
        final payerId = payers[i].id;
        if (payerId == null) continue;

        final payerTransactions = transactions
            .where(
                (t) => t.payerId == payerId && t.type == TransactionType.income)
            .toList();
        for (int j = 0; j < 12; j++) {
          final month = j + 1;
          final hasPayment = payerTransactions.any(
              (t) => t.date.year == _selectedYear && t.date.month == month);
          paymentStatus[i][j] = hasPayment;
        }
      }

      setState(() {
        _availableYears = years;
        _payers = payerNames;
        _paymentStatus = paymentStatus;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading data: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showMonthSummary(int month) async {
    final transactions = await _database.getAllTransactions();
    final monthTransactions = transactions
        .where((t) => t.date.year == _selectedYear && t.date.month == month + 1)
        .toList();

    final totalIncome = monthTransactions
        .where((t) => t.type == TransactionType.income)
        .fold(0.0, (sum, t) => sum + t.amount);

    final totalDeductions = monthTransactions
        .where((t) => t.type == TransactionType.deduction)
        .fold(0.0, (sum, t) => sum + t.amount);

    final totalSavings = totalIncome - totalDeductions;

    // Count total payers who made payments this month
    final payersThisMonth = monthTransactions
        .where((t) => t.type == TransactionType.income)
        .map((t) => t.payerId)
        .toSet()
        .length;

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        elevation: 8,
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with month and year
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_month,
                      color: Theme.of(context).primaryColor,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_months[month]} $_selectedYear',
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).primaryColor,
                                  ),
                        ),
                        Text(
                          'Monthly Summary',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Financial summary cards
              Row(
                children: [
                  Expanded(
                    child: _buildMonthSummaryCard('Income', totalIncome,
                        Icons.arrow_circle_up, Colors.green),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMonthSummaryCard('Expenses', totalDeductions,
                        Icons.arrow_circle_down, Colors.red),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Savings card with progress indicator
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.account_balance_wallet,
                          color: Colors.blue[700],
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Savings',
                          style: TextStyle(
                            color: Colors.blue[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _currencyFormat.format(totalSavings),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                            color: totalSavings >= 0
                                ? Colors.blue[700]
                                : Colors.red,
                          ),
                        ),
                        Text(
                          totalIncome > 0
                              ? '${(totalSavings / totalIncome * 100).toStringAsFixed(1)}%'
                              : '0%',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Visual progress indicator for savings
                    if (totalIncome > 0)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: (totalSavings / totalIncome).clamp(0.0, 1.0),
                          minHeight: 8,
                          backgroundColor: Colors.grey[200],
                          valueColor: AlwaysStoppedAnimation<Color>(
                            totalSavings >= 0 ? Colors.blue : Colors.red,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Additional info
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildInfoItem(
                      'Transactions',
                      monthTransactions.length.toString(),
                      Icons.receipt_long,
                    ),
                    _buildInfoItem(
                      'Income Payers',
                      payersThisMonth.toString(),
                      Icons.people,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Action button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMonthSummaryCard(
      String title, double amount, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: color,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _currencyFormat.format(amount),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 20,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(
          icon,
          color: Colors.grey[600],
          size: 22,
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryItem(String label, double amount, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label),
        Text(
          _currencyFormat.format(amount),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Future<void> _showPaymentDetails(String payerName, int month) async {
    final payers = await _database.getAllPayers();
    final payer = payers.firstWhere((p) => p.name == payerName);
    if (payer.id == null) return;

    final transactions = await _database.getAllTransactions();
    final payerTransactions = transactions
        .where((t) =>
            t.payerId == payer.id &&
            t.date.year == _selectedYear &&
            t.date.month == month + 1 &&
            t.type == TransactionType.income)
        .toList();

    final totalAmount = payerTransactions.fold(0.0, (sum, t) => sum + t.amount);

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.9,
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Income Payment Details',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
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
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.person,
                        color: Theme.of(context).primaryColor,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          payerName,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (payerTransactions.isEmpty)
                  Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.receipt_long,
                          size: 48,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No payment record found!',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ...payerTransactions.map((t) => Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Flexible(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.grey[100],
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          DateFormat('dd MMM yyyy')
                                              .format(t.date),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.green.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        _currencyFormat.format(t.amount),
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green[700],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )),
                          const Divider(height: 32),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Total Paid:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  _currencyFormat.format(totalAmount),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Colors.blue[700],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildYearSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButton<int>(
        value: _selectedYear,
        items: _availableYears.map((year) {
          return DropdownMenuItem<int>(
            value: year,
            child: Text(
              year.toString(),
              style: TextStyle(
                color: Theme.of(context).primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          );
        }).toList(),
        onChanged: (year) {
          if (year != null) {
            setState(() => _selectedYear = year);
            _loadData();
          }
        },
        underline: Container(),
        icon: Icon(
          Icons.arrow_drop_down,
          color: Theme.of(context).primaryColor,
        ),
        isDense: true,
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: TextField(
        decoration: const InputDecoration(
          hintText: 'Search payers...',
          prefixIcon: Icon(Icons.search),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          isDense: true,
        ),
        onChanged: (value) {
          setState(() => _searchQuery = value.toLowerCase());
        },
      ),
    );
  }

  Widget _buildPaymentStatusGrid() {
    final filteredPayers = _payers
        .where((payer) => payer.toLowerCase().contains(_searchQuery))
        .toList();

    return Expanded(
      child: Column(
        children: [
          // Header Row
          Container(
            height: 50,
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              border: Border(
                bottom: BorderSide(color: Colors.grey[300]!),
              ),
            ),
            child: Row(
              children: [
                // Fixed header
                Container(
                  width: 150,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    border: Border(
                      right: BorderSide(color: Colors.grey[300]!),
                    ),
                  ),
                  child: Text(
                    'Payer Name',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                ),
                // Scrollable month headers
                Expanded(
                  child: SingleChildScrollView(
                    controller: _monthHeaderController,
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _months.asMap().entries.map((entry) {
                        final index = entry.key;
                        final month = entry.value;
                        return GestureDetector(
                          onTap: () => _showMonthSummary(index),
                          child: Container(
                            width: 80,
                            alignment: Alignment.center,
                            child: Text(
                              month,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).primaryColor,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Scrollable Grid Content
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Fixed payer name column
                SizedBox(
                  width: 150,
                  child: ListView.builder(
                    controller: _namesListController,
                    itemCount: filteredPayers.length,
                    itemBuilder: (context, index) {
                      return Container(
                        height: 50,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border(
                            right: BorderSide(color: Colors.grey[300]!),
                            bottom: BorderSide(color: Colors.grey[200]!),
                          ),
                        ),
                        child: Text(
                          filteredPayers[index],
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      );
                    },
                  ),
                ),

                // Scrollable status grid
                Expanded(
                  child: SingleChildScrollView(
                    controller: _statusRowController,
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: 80 * 12, // 12 months * 80 width
                      child: ListView.builder(
                        controller: _statusGridController,
                        itemCount: filteredPayers.length,
                        itemBuilder: (context, payerIndex) {
                          final payerPosition =
                              _payers.indexOf(filteredPayers[payerIndex]);
                          return SizedBox(
                            height: 50,
                            child: Row(
                              children:
                                  _months.asMap().entries.map((monthEntry) {
                                final monthIndex = monthEntry.key;
                                final isPaid =
                                    _paymentStatus[payerPosition][monthIndex];
                                return GestureDetector(
                                  onTap: isPaid
                                      ? () => _showPaymentDetails(
                                          filteredPayers[payerIndex],
                                          monthIndex)
                                      : null,
                                  child: Container(
                                    width: 80,
                                    height: 50,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      border: Border(
                                        bottom: BorderSide(
                                            color: Colors.grey[200]!),
                                      ),
                                    ),
                                    child: Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color: isPaid
                                            ? Colors.green.withOpacity(0.1)
                                            : Colors.red.withOpacity(0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        isPaid ? Icons.check : Icons.close,
                                        color:
                                            isPaid ? Colors.green : Colors.red,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    // Calculate months with payments (months where at least one payment was made)
    final monthsWithPayments = List.generate(12, (monthIndex) {
      return _paymentStatus.any((row) => row[monthIndex]);
    }).where((hasPayment) => hasPayment).length;

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Monthly Summary',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildSummaryItemCard(
                    'Total Payers',
                    _payers.length.toString(),
                    Icons.people,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildSummaryItemCard(
                    'Months with Payments',
                    monthsWithPayments.toString(),
                    Icons.calendar_today,
                    Colors.green,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItemCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction History'),
        actions: [
          _buildYearSelector(),
          const SizedBox(width: 16),
          IconButton(
            icon: const Icon(Icons.bar_chart),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MonthlyAmountChartScreen(
                    selectedYear: _selectedYear,
                  ),
                ),
              );
            },
            tooltip: 'View Monthly Amounts',
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildSearchBar(),
                const SizedBox(height: 8),
                _buildSummaryCard(),
                _buildPaymentStatusGrid(),
              ],
            ),
    );
  }
}
