import 'package:flutter/material.dart';
import '../models/category.dart';
import '../services/database_service.dart';
import '../services/language_service.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

class CategoryScreen extends StatefulWidget {
  const CategoryScreen({Key? key}) : super(key: key);

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  final _database = DatabaseService.instance;
  final _formKey = GlobalKey<FormState>();
  final _categoryNameController = TextEditingController();
  final _languageService = LanguageService.instance;
  List<Category> _categories = [];
  bool _isLoading = false;
  StreamSubscription<String>? _languageChangeSubscription;
  String _currentUrduFont = 'NotoNastaliqUrdu'; // Default Urdu font

  @override
  void initState() {
    super.initState();
    _initializeDatabase();
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

  Future<void> _initializeDatabase() async {
    try {
      await _loadCategories();
    } catch (e) {
      await _database.deleteDatabase();
      await _loadCategories();
    }
  }

  @override
  void dispose() {
    _categoryNameController.dispose();
    _languageChangeSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    setState(() => _isLoading = true);
    final categories = await _database.getAllCategories();
    setState(() {
      _categories = categories;
      _isLoading = false;
    });
  }

  Future<void> _addCategory() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() => _isLoading = true);
      try {
        final category = await _database.createCategory(
          Category(name: _categoryNameController.text.trim()),
        );
        _categoryNameController.clear();
        await _loadCategories();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _languageService.t('category_added_successfully') ??
                    'Category added Successfully',
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
                _languageService.t('error_unique_category_name') ??
                    'Error: Category name must be unique',
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

  Future<void> _deleteCategory(Category category) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            _languageService.t('delete_category') ?? 'Delete Category',
            style: _getUrduAwareTextStyle(const TextStyle()),
          ),
          content: Text(
            (_languageService.t('confirm_delete_category') ??
                    'Are you sure you want to delete "{name}"?')
                .replaceAll('{name}', category.name),
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
        await _database.deleteCategory(category.id!);
        await _loadCategories();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _languageService.t('category_deleted_successfully') ??
                    'Category deleted Successfully',
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
                _languageService.t('error_deleting_category') ??
                    'Error deleting category',
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
          _languageService.t('manage_expense_categories') ?? 'Categories',
          style: _getUrduAwareTextStyle(const TextStyle()),
        ),
        backgroundColor: Colors.red,
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
                  Colors.red.withOpacity(0.1),
                  Colors.white,
                ],
              ),
            ),
          ),
          // Main content
          Column(
            children: [
              // Add Category Form
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
                        controller: _categoryNameController,
                        decoration: InputDecoration(
                          labelText:
                              _languageService.t('enter_category_name') ??
                                  'Enter Category Name',
                          labelStyle: _getUrduAwareTextStyle(TextStyle(
                            color: Colors.grey[700],
                          )),
                          prefixIcon: const Icon(Icons.category_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Colors.grey.withOpacity(0.3),
                            ),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return _languageService
                                    .t('please_enter_category_name') ??
                                'Please enter a category name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _addCategory,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
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
                                _languageService.t('add_category') ??
                                    'ADD CATEGORY',
                                style: _getUrduAwareTextStyle(const TextStyle(
                                  fontWeight: FontWeight.bold,
                                )),
                              ),
                      ),
                    ],
                  ),
                ),
              ),

              // Categories List Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  children: [
                    const Icon(
                      Icons.list_alt,
                      color: Colors.red,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _languageService.t('categories_list') ??
                          'Categories List',
                      style: _getUrduAwareTextStyle(const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      )),
                    ),
                    const Spacer(),
                    Text(
                      (_languageService.t('items_count') ?? '{count} items')
                          .replaceAll('{count}', _categories.length.toString()),
                      style: _getUrduAwareTextStyle(TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      )),
                    ),
                  ],
                ),
              ),

              // Categories List
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Colors.red,
                        ),
                      )
                    : _categories.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.category_outlined,
                                  size: 64,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _languageService.t('no_categories_yet') ??
                                      'No categories yet',
                                  style: _getUrduAwareTextStyle(TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 16,
                                  )),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _languageService
                                          .t('add_category_to_get_started') ??
                                      'Add a new category to get started',
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
                            itemCount: _categories.length,
                            itemBuilder: (context, index) {
                              final category = _categories[index];
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
                                      color: Colors.red.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Center(
                                      child: Text(
                                        '${index + 1}',
                                        style: const TextStyle(
                                          color: Colors.red,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    category.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  trailing: IconButton(
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      color: Colors.red,
                                    ),
                                    onPressed: () => _deleteCategory(category),
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
