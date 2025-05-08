import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/imaam_salary.dart';
import '../models/transaction.dart';
import '../services/database_service.dart';
import '../widgets/translated_text.dart';

class ImaamSalaryScreen extends StatefulWidget {
  const ImaamSalaryScreen({Key? key}) : super(key: key);

  @override
  State<ImaamSalaryScreen> createState() => _ImaamSalaryScreenState();
}

class _ImaamSalaryScreenState extends State<ImaamSalaryScreen> {
  final _database = DatabaseService.instance;
  final _currencyFormat = NumberFormat.currency(
    symbol: '₹',
    decimalDigits: 1,
    locale: 'en_IN',
  );
  List<ImaamSalary> _salaries = [];
  List<Transaction> _relatedDeductions = [];
  bool _isLoading = true;
  double _defaultAmount = 0.0;
  bool _isFirstTime = true;

  // Categories related to Imaam/Maulana salary
  final List<String> _salaryCategories = [
    'Salary',
    'Tankhwah',
    'Maulana Salary',
    'Maulana Payment',
    'Imaam Salary',
    'Maulana Tankhwah',
    'Imaam Tankhwah',
    'Imaam Payment',
    'Imam Tankhwah',
    'Imam Payment',
    'Imam Salary',
    'तनख्वाह',
    'सैलरी',
    'मौलाना तनख्वाह',
    'इमाम तनख्वाह',
    'मौलाना तंख्वाह',
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final salaries = await _database.getAllImaamSalaries();
      final transactions = await _database.getAllTransactions();

      // Filter deductions related to Imaam/Maulana salary
      final relatedDeductions = transactions
          .where((t) =>
              t.type == TransactionType.deduction &&
              _salaryCategories.contains(t.category))
          .toList();

      // Check each salary and mark as paid if there are matching deductions
      for (var salary in salaries) {
        if (!salary.isPaid) {
          // Check if there are any deductions for this month
          final hasDeductions = relatedDeductions.any((deduction) =>
              deduction.date.year == salary.year &&
              deduction.date.month == salary.month);

          if (hasDeductions) {
            // Mark salary as paid
            final updatedSalary = ImaamSalary(
              id: salary.id,
              year: salary.year,
              month: salary.month,
              isPaid: true,
              paidDate: DateTime.now(),
              amount: salary.amount,
              notes: salary.notes,
            );
            await _database.updateImaamSalary(updatedSalary);
          }
        }
      }

      // Reload salaries after potential updates
      final updatedSalaries = await _database.getAllImaamSalaries();

      setState(() {
        _salaries = updatedSalaries;
        _relatedDeductions = relatedDeductions;
        if (updatedSalaries.isNotEmpty) {
          _defaultAmount = updatedSalaries.first.amount;
          _isFirstTime = false;
        }
      });

      // Check if we need to add the current month
      if (!_isFirstTime) {
        await _addCurrentMonthIfNeeded();
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addCurrentMonthIfNeeded() async {
    final now = DateTime.now();
    final year = now.year;
    final month = now.month;

    // Check if current month already exists
    final existing = await _database.getImaamSalary(year, month);
    if (existing == null) {
      // Add current month with default amount
      final newSalary = ImaamSalary(
        year: year,
        month: month,
        isPaid: false,
        amount: _defaultAmount,
      );
      await _database.createImaamSalary(newSalary);
      await _loadData(); // Reload data to show the new month
    }
  }

  Future<void> _addNewMonth() async {
    final now = DateTime.now();
    final year = now.year;
    final month = now.month;

    // Check if already exists
    final existing = await _database.getImaamSalary(year, month);
    if (existing != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This month already exists')),
      );
      return;
    }

    // Show dialog to set default amount
    final amountController = TextEditingController(
      text: _defaultAmount.toString(),
    );

    final result = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set Default Amount'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'This amount will be used for all future months. You can edit it later.',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: amountController,
              decoration: const InputDecoration(
                labelText: 'Default Amount',
                prefixText: '₹ ',
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final amount =
                  double.tryParse(amountController.text) ?? _defaultAmount;
              Navigator.pop(context, amount);
            },
            child: const Text('Set'),
          ),
        ],
      ),
    );

    if (result != null) {
      setState(() {
        _defaultAmount = result;
        _isFirstTime = false;
      });

      final newSalary = ImaamSalary(
        year: year,
        month: month,
        isPaid: false,
        amount: result,
      );

      await _database.createImaamSalary(newSalary);
      await _loadData();
    }
  }

  Future<void> _markAsPaid(ImaamSalary salary) async {
    final updatedSalary = ImaamSalary(
      id: salary.id,
      year: salary.year,
      month: salary.month,
      isPaid: true,
      paidDate: DateTime.now(),
      amount: salary.amount,
      notes: salary.notes,
    );
    await _database.updateImaamSalary(updatedSalary);
    await _loadData();
  }

  Future<void> _markAsUnpaid(ImaamSalary salary) async {
    final updatedSalary = ImaamSalary(
      id: salary.id,
      year: salary.year,
      month: salary.month,
      isPaid: false,
      paidDate: null,
      amount: salary.amount,
      notes: salary.notes,
    );
    await _database.updateImaamSalary(updatedSalary);
    await _loadData();
  }

  Future<void> _editSalary(ImaamSalary salary) async {
    final amountController = TextEditingController(
      text: salary.amount.toString(),
    );
    final notesController = TextEditingController(
      text: salary.notes ?? '',
    );

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Salary'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountController,
              decoration: const InputDecoration(
                labelText: 'Amount',
                prefixText: '₹ ',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: notesController,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final amount =
                  double.tryParse(amountController.text) ?? salary.amount;
              Navigator.pop(context, {
                'amount': amount,
                'notes': notesController.text,
              });
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null) {
      final updatedSalary = ImaamSalary(
        id: salary.id,
        year: salary.year,
        month: salary.month,
        isPaid: salary.isPaid,
        paidDate: salary.paidDate,
        amount: result['amount'],
        notes: result['notes'],
      );
      await _database.updateImaamSalary(updatedSalary);
      await _loadData();
    }
  }

  Widget _buildSummaryCard(
      String title, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSalaryCard(ImaamSalary salary) {
    final date = DateTime(salary.year, salary.month);
    final monthName = DateFormat('MMMM yyyy').format(date);
    final isCurrentMonth =
        date.year == DateTime.now().year && date.month == DateTime.now().month;

    // Check if there are any deductions for this month
    final hasDeductions = _relatedDeductions.any((deduction) =>
        deduction.date.year == salary.year &&
        deduction.date.month == salary.month);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isCurrentMonth
                  ? Colors.blue.withOpacity(0.1)
                  : Colors.grey.withOpacity(0.05),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isCurrentMonth ? Colors.blue : Colors.grey,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.calendar_today,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        monthName,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: isCurrentMonth ? Colors.blue : Colors.black87,
                        ),
                      ),
                      if (isCurrentMonth)
                        Text(
                          'Current Month',
                          style: TextStyle(
                            color: Colors.blue,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: salary.isPaid
                        ? Colors.green.withOpacity(0.1)
                        : Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    salary.isPaid ? 'Paid' : 'Unpaid',
                    style: TextStyle(
                      color: salary.isPaid ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Amount',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _currencyFormat.format(salary.amount),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      if (salary.notes != null && salary.notes!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          salary.notes!,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                      if (hasDeductions) ...[
                        const SizedBox(height: 8),
                        Text(
                          'From Deductions',
                          style: TextStyle(
                            color: Colors.red,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        salary.isPaid
                            ? Icons.check_circle
                            : Icons.circle_outlined,
                        color: salary.isPaid ? Colors.green : Colors.grey,
                      ),
                      onPressed: () {
                        if (salary.isPaid) {
                          _markAsUnpaid(salary);
                        } else {
                          _markAsPaid(salary);
                        }
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => _editSalary(salary),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Calculate total deductions
    final totalDeductions = _relatedDeductions.fold<double>(
      0,
      (sum, deduction) => sum + deduction.amount,
    );

    // Calculate total amount (only paid salaries)
    final totalAmount = _salaries
        .where((salary) => salary.isPaid)
        .fold<double>(0, (sum, salary) => sum + salary.amount);

    // Calculate paid amount (only paid salaries)
    final paidAmount = _salaries
        .where((salary) => salary.isPaid)
        .fold<double>(0, (sum, salary) => sum + salary.amount);

    // Calculate unpaid amount (unpaid salaries)
    final unpaidAmount = _salaries
        .where((salary) => !salary.isPaid)
        .fold<double>(0, (sum, salary) => sum + salary.amount);

    return Scaffold(
      appBar: AppBar(
        title: const TranslatedText('imaam_salary'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () async {
              final amountController = TextEditingController(
                text: _defaultAmount.toString(),
              );

              final result = await showDialog<double>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Edit Default Salary'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'This amount will be used for all future months.',
                        style: TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: amountController,
                        decoration: const InputDecoration(
                          labelText: 'Default Amount',
                          prefixText: '₹ ',
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () {
                        final amount = double.tryParse(amountController.text) ??
                            _defaultAmount;
                        Navigator.pop(context, amount);
                      },
                      child: const Text('Save'),
                    ),
                  ],
                ),
              );

              if (result != null) {
                setState(() {
                  _defaultAmount = result;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Default salary amount updated'),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.00),
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(24),
                          bottomRight: Radius.circular(24),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Salary Overview',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  'Default: ${_currencyFormat.format(_defaultAmount)}',
                                  style: TextStyle(
                                    color: Colors.blue[700],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _buildSummaryCard(
                                  'Total Amount',
                                  _currencyFormat.format(totalAmount),
                                  Colors.blue,
                                  Icons.account_balance_wallet,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildSummaryCard(
                                  'Paid',
                                  _currencyFormat.format(paidAmount),
                                  Colors.green,
                                  Icons.check_circle,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _buildSummaryCard(
                                  'Pending',
                                  _currencyFormat.format(unpaidAmount),
                                  Colors.orange,
                                  Icons.pending_actions,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildSummaryCard(
                                  'Deductions',
                                  _currencyFormat.format(totalDeductions),
                                  Colors.red,
                                  Icons.money_off,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                      child: Text(
                        'Salary History',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                    ),
                  ),
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _buildSalaryCard(_salaries[index]),
                      childCount: _salaries.length,
                    ),
                  ),
                ],
              ),
            ),
      floatingActionButton: _isFirstTime
          ? FloatingActionButton.extended(
              onPressed: _addNewMonth,
              icon: const Icon(Icons.add),
              label: const Text('Set Default Amount'),
              backgroundColor: Colors.blue,
            )
          : null,
    );
  }
}
