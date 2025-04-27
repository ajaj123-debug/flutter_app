import 'package:flutter/material.dart';
import '../models/transaction.dart';
import '../services/database_service.dart';

enum SortParameter { payer, month, year }

class AdminScreen extends StatefulWidget {
  const AdminScreen({Key? key}) : super(key: key);

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final DatabaseService _databaseService = DatabaseService.instance;
  List<Transaction> _transactions = [];
  Map<int, String> _payerNames = {};
  SortParameter _currentSortParameter = SortParameter.payer;
  bool _isAscending = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final transactions = await _databaseService.getAllTransactions();
    final payers = await _databaseService.getAllPayers();

    setState(() {
      _transactions = transactions;
      _payerNames = {
        for (var p in payers)
          if (p.id != null) p.id!: p.name
      };
      _isLoading = false;
    });
  }

  Future<void> _deleteTransaction(Transaction transaction) async {
    if (transaction.id != null) {
      final bool? confirm = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Confirm Deletion'),
            content: Text(
                'Are you sure you want to delete this ${transaction.type == TransactionType.income ? 'income' : 'deduction'} transaction of ₹${transaction.amount}?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red,
                ),
                child: const Text('Delete'),
              ),
            ],
          );
        },
      );

      if (confirm == true) {
        setState(() => _isLoading = true);
        await _databaseService.deleteTransaction(transaction.id!);
        await _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Transaction deleted Successfully'),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}';
  }

  List<Transaction> _sortTransactions(List<Transaction> transactions) {
    return List.from(transactions)
      ..sort((a, b) {
        switch (_currentSortParameter) {
          case SortParameter.payer:
            final payerA = _payerNames[a.payerId] ?? '';
            final payerB = _payerNames[b.payerId] ?? '';
            return _isAscending
                ? payerA.compareTo(payerB)
                : payerB.compareTo(payerA);
          case SortParameter.month:
            return _isAscending
                ? a.date.month.compareTo(b.date.month)
                : b.date.month.compareTo(a.date.month);
          case SortParameter.year:
            return _isAscending
                ? a.date.year.compareTo(b.date.year)
                : b.date.year.compareTo(a.date.year);
        }
      });
  }

  @override
  Widget build(BuildContext context) {
    final incomeTransactions = _sortTransactions(
        _transactions.where((t) => t.type == TransactionType.income).toList());
    final deductionTransactions = _sortTransactions(_transactions
        .where((t) => t.type == TransactionType.deduction)
        .toList());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Panel', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.red,
        elevation: 0,
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 8.0),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: const Icon(Icons.sort, color: Colors.white),
                ),
                Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  decoration: BoxDecoration(
                    border: Border(
                      left: BorderSide(color: Colors.white.withOpacity(0.2)),
                    ),
                  ),
                  child: DropdownButton<SortParameter>(
                    value: _currentSortParameter,
                    dropdownColor: Colors.red,
                    style: const TextStyle(color: Colors.white),
                    underline: Container(),
                    icon: const Icon(Icons.keyboard_arrow_down,
                        color: Colors.white),
                    items: const [
                      DropdownMenuItem(
                        value: SortParameter.payer,
                        child: Row(
                          children: [
                            Icon(Icons.person, color: Colors.white),
                            SizedBox(width: 8),
                            Text('Payer',
                                style: TextStyle(color: Colors.white)),
                          ],
                        ),
                      ),
                      DropdownMenuItem(
                        value: SortParameter.month,
                        child: Row(
                          children: [
                            Icon(Icons.calendar_today, color: Colors.white),
                            SizedBox(width: 8),
                            Text('Month',
                                style: TextStyle(color: Colors.white)),
                          ],
                        ),
                      ),
                      DropdownMenuItem(
                        value: SortParameter.year,
                        child: Row(
                          children: [
                            Icon(Icons.calendar_month, color: Colors.white),
                            SizedBox(width: 8),
                            Text('Year', style: TextStyle(color: Colors.white)),
                          ],
                        ),
                      ),
                    ],
                    onChanged: (SortParameter? newValue) {
                      if (newValue != null) {
                        setState(() {
                          _currentSortParameter = newValue;
                        });
                      }
                    },
                  ),
                ),
                Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  decoration: BoxDecoration(
                    border: Border(
                      left: BorderSide(color: Colors.white.withOpacity(0.2)),
                    ),
                  ),
                  child: IconButton(
                    icon: Icon(
                      _isAscending ? Icons.arrow_upward : Icons.arrow_downward,
                      color: Colors.white,
                    ),
                    onPressed: () {
                      setState(() {
                        _isAscending = !_isAscending;
                      });
                    },
                    tooltip: _isAscending ? 'Ascending' : 'Descending',
                  ),
                ),
              ],
            ),
          ),
        ],
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
                  Colors.red.withOpacity(0.1),
                  Colors.white,
                ],
              ),
            ),
          ),
          RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                    // Income Transactions Section
                Container(
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
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.arrow_upward,
                                  color: Colors.green,
                                ),
                              ),
                              const SizedBox(width: 12),
                      const Text(
                        'All Savings Till Now',
                        style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '${incomeTransactions.length} items',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                      if (incomeTransactions.isEmpty)
                            Center(
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.savings_outlined,
                                    size: 64,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No savings transactions yet',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            ...incomeTransactions.map((transaction) =>
                                Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[50],
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.grey.withOpacity(0.1),
                                    ),
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
                                      child: const Center(
                                        child: Icon(
                                          Icons.person,
                                          color: Colors.green,
                                        ),
                                      ),
                                    ),
                                    title: Text(
                                      _payerNames[transaction.payerId] ??
                                          'Unknown Payer',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    subtitle: Text(
                                      _formatDate(transaction.date),
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 12,
                                      ),
                                    ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                        Text(
                                          '₹${transaction.amount}',
                                          style: const TextStyle(
                                            color: Colors.green,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                    IconButton(
                                          icon: const Icon(
                                            Icons.delete_outline,
                                            color: Colors.red,
                                          ),
                                      onPressed: () =>
                                          _deleteTransaction(transaction),
                                    ),
                                  ],
                                ),
                              ),
                            )),
                    ],
                  ),
                ),

                    // Deduction Transactions Section
                Container(
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
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.arrow_downward,
                                  color: Colors.red,
                                ),
                              ),
                              const SizedBox(width: 12),
                      const Text(
                        'All Deductions Till Now',
                        style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '${deductionTransactions.length} items',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                      if (deductionTransactions.isEmpty)
                            Center(
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.money_off_outlined,
                                    size: 64,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No deduction transactions yet',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            ...deductionTransactions.map((transaction) =>
                                Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[50],
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.grey.withOpacity(0.1),
                                    ),
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
                                        color: Colors.red.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: const Center(
                                        child: Icon(
                                          Icons.category,
                                          color: Colors.red,
                                        ),
                                      ),
                                    ),
                                    title: Text(
                                      transaction.category,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    subtitle: Text(
                                      _formatDate(transaction.date),
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 12,
                                      ),
                                    ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                        Text(
                                          '₹${transaction.amount}',
                                          style: const TextStyle(
                                            color: Colors.red,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                    IconButton(
                                          icon: const Icon(
                                            Icons.delete_outline,
                                            color: Colors.red,
                                          ),
                                      onPressed: () =>
                                          _deleteTransaction(transaction),
                                    ),
                                  ],
                                ),
                              ),
                            )),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.1),
              child: const Center(
                child: CircularProgressIndicator(
                  color: Colors.red,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
