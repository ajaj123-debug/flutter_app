import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/payer.dart';
import '../models/category.dart';
import '../models/transaction.dart';
import '../services/database_service.dart';
import 'role_selection_screen.dart';
import 'package:intl/intl.dart';
import 'payer_screen.dart';
import 'category_screen.dart';
import '../widgets/translated_text.dart';

class ManagerScreen extends StatefulWidget {
  // This screen now represents the "Accounts" tab content
  const ManagerScreen({Key? key}) : super(key: key);

  @override
  State<ManagerScreen> createState() => _ManagerScreenState();
}

class _ManagerScreenState extends State<ManagerScreen> {
  final _database = DatabaseService.instance;
  final _incomeFormKey = GlobalKey<FormState>(); // Separate form key for income
  final _deductionFormKey =
      GlobalKey<FormState>(); // Separate form key for deduction
  final _incomeAmountController = TextEditingController();
  final _deductionAmountController = TextEditingController();
  Payer? _selectedPayer;
  Category? _selectedCategory;
  List<Payer> _payers = [];
  List<Category> _categories = [];
  DateTime _selectedDate = DateTime.now();
  bool _isIncomeExpanded = true;
  bool _isDeductionExpanded = true;

  @override
  void initState() {
    super.initState();
    _loadData();
    _isIncomeExpanded = true;
    _isDeductionExpanded = true;
  }

  @override
  void dispose() {
    _incomeAmountController.dispose();
    _deductionAmountController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final payers = await _database.getAllPayers();
    final categories = await _database.getAllCategories();

    setState(() {
      _payers = payers;
      _categories = categories;
      if (payers.isNotEmpty) {
        _selectedPayer = payers.first;
      }
      if (categories.isNotEmpty) {
        _selectedCategory = categories.first;
      }
    });
  }

  Future<void> _handleLogout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_role');
    await prefs.setBool('first_launch', true);

    if (!context.mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => const RoleSelectionScreen(),
      ),
    );
  }

  Future<void> _addTransaction(TransactionType type, double amount) async {
    if (_selectedPayer != null && _selectedCategory != null) {
      await _database.createTransaction(
        Transaction(
          payerId: _selectedPayer!.id!,
          amount: amount,
          type: type,
          category: type == TransactionType.income
              ? _selectedPayer!.name
              : _selectedCategory!.name,
          date: _selectedDate,
        ),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            type == TransactionType.income
                ? '₹${amount.toStringAsFixed(0)} added to ${_selectedPayer!.name} on ${DateFormat('dd-MM-yyyy').format(_selectedDate)}'
                : '₹${amount.toStringAsFixed(0)} deducted from ${_selectedCategory!.name} on ${DateFormat('dd-MM-yyyy').format(_selectedDate)}',
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          backgroundColor:
              type == TransactionType.income ? Colors.green : Colors.red,
          duration: const Duration(milliseconds: 900),
          margin: const EdgeInsets.all(10),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        ),
      );
    }
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
    }
  }

  Future<void> _exportToGoogleSheets() async {
    // TODO: Implement Google Sheets export
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Google Sheets export coming soon...'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildTransactionCards(),
        ],
      ),
    );
  }

  Widget _buildTransactionCards() {
    return Column(
      children: [
        _buildExpandableCard(
          title: 'add_income',
          icon: Icons.add_circle_outline,
          iconColor: Colors.green,
          isExpanded: _isIncomeExpanded,
          onToggle: () {
            setState(() {
              _isIncomeExpanded = !_isIncomeExpanded;
            });
          },
          child: _buildIncomeForm(),
        ),
        const SizedBox(height: 12),
        _buildExpandableCard(
          title: 'add_deduction',
          icon: Icons.remove_circle_outline,
          iconColor: Colors.red,
          isExpanded: _isDeductionExpanded,
          onToggle: () {
            setState(() {
              _isDeductionExpanded = !_isDeductionExpanded;
            });
          },
          child: _buildDeductionForm(),
        ),
      ],
    );
  }

  Widget _buildExpandableCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required bool isExpanded,
    required VoidCallback onToggle,
    required Widget child,
  }) {
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
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      if (title == 'add_income') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const PayerScreen()),
                        ).then((_) => _loadData());
                      } else if (title == 'add_deduction') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const CategoryScreen()),
                        ).then((_) => _loadData());
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: iconColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, color: iconColor, size: 24),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TranslatedText(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.grey,
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: child,
            ),
        ],
      ),
    );
  }

  Widget _buildIncomeForm() {
    return Form(
      key: _incomeFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          _buildDropdownField(
            value: _selectedPayer,
            items: _payers.map((payer) {
              return DropdownMenuItem(
                value: payer,
                child: Text(payer.name),
              );
            }).toList(),
            onChanged: (Payer? value) {
              setState(() {
                _selectedPayer = value;
              });
            },
            labelText: 'select_payer',
            validator: (value) => value == null ? 'please_select_payer' : null,
          ),
          const SizedBox(height: 16),
          _buildAmountField(
            controller: _incomeAmountController,
            labelText: 'enter_amount',
            onDateSelected: () => _selectDate(context),
            selectedDate: _selectedDate,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'please_enter_amount';
              }
              if (double.tryParse(value) == null) {
                return 'please_enter_valid_number';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          _buildDateDisplay(_selectedDate),
          const SizedBox(height: 16),
          _buildSubmitButton(
            onPressed: () {
              if (_incomeFormKey.currentState?.validate() ?? false) {
                final amount = double.tryParse(_incomeAmountController.text);
                if (amount != null) {
                  _addTransaction(TransactionType.income, amount);
                  setState(() {
                    _selectedDate = DateTime.now();
                  });
                }
              }
            },
            label: 'add_amount',
            color: Colors.green,
          ),
        ],
      ),
    );
  }

  Widget _buildDeductionForm() {
    return Form(
      key: _deductionFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          _buildDropdownField(
            value: _selectedCategory,
            items: _categories.map((category) {
              return DropdownMenuItem(
                value: category,
                child: Text(category.name),
              );
            }).toList(),
            onChanged: (Category? value) {
              setState(() {
                _selectedCategory = value;
              });
            },
            labelText: 'select_category',
            validator: (value) =>
                value == null ? 'please_select_category' : null,
          ),
          const SizedBox(height: 16),
          _buildAmountField(
            controller: _deductionAmountController,
            labelText: 'enter_deduction_amount',
            onDateSelected: () => _selectDate(context),
            selectedDate: _selectedDate,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'please_enter_amount';
              }
              if (double.tryParse(value) == null) {
                return 'please_enter_valid_number';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          _buildDateDisplay(_selectedDate),
          const SizedBox(height: 16),
          _buildSubmitButton(
            onPressed: () {
              if (_deductionFormKey.currentState?.validate() ?? false) {
                final amount = double.tryParse(_deductionAmountController.text);
                if (amount != null) {
                  _addTransaction(TransactionType.deduction, amount);
                  _deductionAmountController.clear();
                  setState(() {
                    _selectedDate = DateTime.now();
                  });
                }
              }
            },
            label: 'deduct_amount',
            color: Colors.red,
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownField<T>({
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
    required String labelText,
    required String? Function(T?) validator,
  }) {
    return DropdownButtonFormField<T>(
      value: value,
      items: items,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: labelText.tr,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: Colors.grey.withOpacity(0.05),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      validator: (value) {
        final error = validator(value);
        return error?.tr;
      },
      dropdownColor: Colors.white,
      icon: const Icon(Icons.arrow_drop_down),
      isExpanded: true,
    );
  }

  Widget _buildAmountField({
    required TextEditingController controller,
    required String labelText,
    required VoidCallback onDateSelected,
    required DateTime selectedDate,
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: labelText.tr,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: Colors.grey.withOpacity(0.05),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        suffixIcon: IconButton(
          icon: const Icon(Icons.calendar_today),
          onPressed: onDateSelected,
          tooltip: '${'select_date'.tr} (${DateFormat('dd-MM-yyyy').format(selectedDate)})',
        ),
      ),
      validator: (value) {
        final error = validator(value);
        return error?.tr;
      },
    );
  }

  Widget _buildDateDisplay(DateTime date) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          Text(
            '${'selected_date'.tr}: ${DateFormat('dd-MM-yyyy').format(date)}',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton({
    required VoidCallback onPressed,
    required String label,
    required Color color,
  }) {
    // Special handling for the income form button
    if (label == 'add_amount') {
      return SizedBox(
        width: double.infinity,
        height: 50,
        child: Row(
          children: [
            // Main button (75% width)
            Expanded(
              flex: 3,
              child: ElevatedButton(
                onPressed: onPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(12),
                      bottomLeft: Radius.circular(12),
                    ),
                  ),
                  elevation: 0,
                ),
                child: TranslatedText(
                  label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            // Next payer button (25% width)
            Expanded(
              flex: 1,
              child: ElevatedButton(
                onPressed: () {
                  if (_payers.isNotEmpty) {
                    setState(() {
                      final currentIndex = _payers.indexOf(_selectedPayer!);
                      final nextIndex = (currentIndex + 1) % _payers.length;
                      _selectedPayer = _payers[nextIndex];
                    });
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: color.withOpacity(0.8),
                  foregroundColor: Colors.white,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.only(
                      topRight: Radius.circular(12),
                      bottomRight: Radius.circular(12),
                    ),
                  ),
                  elevation: 0,
                ),
                child: const Icon(Icons.arrow_forward),
              ),
            ),
          ],
        ),
      );
    }

    // Special handling for the deduction form button
    if (label == 'deduct_amount') {
      return SizedBox(
        width: double.infinity,
        height: 50,
        child: Row(
          children: [
            // Main button (75% width)
            Expanded(
              flex: 3,
              child: ElevatedButton(
                onPressed: onPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(12),
                      bottomLeft: Radius.circular(12),
                    ),
                  ),
                  elevation: 0,
                ),
                child: TranslatedText(
                  label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            // Next category button (25% width)
            Expanded(
              flex: 1,
              child: ElevatedButton(
                onPressed: () {
                  if (_categories.isNotEmpty) {
                    setState(() {
                      final currentIndex =
                          _categories.indexOf(_selectedCategory!);
                      final nextIndex = (currentIndex + 1) % _categories.length;
                      _selectedCategory = _categories[nextIndex];
                    });
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: color.withOpacity(0.8),
                  foregroundColor: Colors.white,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.only(
                      topRight: Radius.circular(12),
                      bottomRight: Radius.circular(12),
                    ),
                  ),
                  elevation: 0,
                ),
                child: const Icon(Icons.arrow_forward),
              ),
            ),
          ],
        ),
      );
    }

    // Default button for other cases
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: TranslatedText(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
