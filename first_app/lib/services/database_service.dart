import 'package:sqflite/sqflite.dart' hide Transaction;
import 'package:path/path.dart';
import '../models/account.dart';
import '../models/transaction.dart';
import '../models/payer.dart';
import '../models/category.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;

  DatabaseService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('mosque_accounts.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 3,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add payers table if it doesn't exist
      await db.execute('''
        CREATE TABLE IF NOT EXISTS payers (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL UNIQUE
        )
      ''');

      // Add categories table if it doesn't exist
      await db.execute('''
        CREATE TABLE IF NOT EXISTS categories (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL UNIQUE
        )
      ''');
    }
    
    if (oldVersion < 3) {
      // Create new transactions table with payer_id
      await db.execute('''
        CREATE TABLE new_transactions (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          payer_id INTEGER NOT NULL,
          amount REAL NOT NULL,
          type TEXT NOT NULL,
          category TEXT NOT NULL,
          date TEXT NOT NULL,
          FOREIGN KEY (payer_id) REFERENCES payers (id)
        )
      ''');
      
      // Copy data from old table to new table (setting a default payer if needed)
      await db.execute('''
        INSERT INTO new_transactions (payer_id, amount, type, category, date)
        SELECT 1, amount, type, category, date FROM transactions
      ''');
      
      // Drop old table
      await db.execute('DROP TABLE transactions');
      
      // Rename new table to transactions
      await db.execute('ALTER TABLE new_transactions RENAME TO transactions');
    }
  }

  Future<void> _createDB(Database db, int version) async {
    // Create payers table first since transactions will reference it
    await db.execute('''
      CREATE TABLE payers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE
      )
    ''');

    await db.execute('''
      CREATE TABLE transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        payer_id INTEGER NOT NULL,
        amount REAL NOT NULL,
        type TEXT NOT NULL,
        category TEXT NOT NULL,
        date TEXT NOT NULL,
        FOREIGN KEY (payer_id) REFERENCES payers (id)
      )
    ''');

    // Add categories table
    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE
      )
    ''');
  }

  // Account operations
  Future<Account> createAccount(Account account) async {
    final db = await database;
    final id = await db.insert('accounts', account.toMap());
    return Account(
      id: id,
      name: account.name,
      balance: account.balance,
    );
  }

  Future<List<Account>> getAllAccounts() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('accounts');
    return List.generate(maps.length, (i) => Account.fromMap(maps[i]));
  }

  Future<void> updateAccount(Account account) async {
    final db = await database;
    await db.update(
      'accounts',
      account.toMap(),
      where: 'id = ?',
      whereArgs: [account.id],
    );
  }

  // Transaction operations
  Future<Transaction> createTransaction(Transaction transaction) async {
    final db = await database;
    final id = await db.insert('transactions', transaction.toMap());
    
    return Transaction(
      id: id,
      payerId: transaction.payerId,
      amount: transaction.amount,
      type: transaction.type,
      category: transaction.category,
      date: transaction.date,
    );
  }

  Future<void> deleteTransaction(int id) async {
    final db = await database;
    await db.delete(
      'transactions',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Transaction>> getPayerTransactions(int payerId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      where: 'payer_id = ?',
      whereArgs: [payerId],
      orderBy: 'date DESC',
    );
    return List.generate(maps.length, (i) => Transaction.fromMap(maps[i]));
  }

  Future<List<Transaction>> getAllTransactions() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      orderBy: 'date DESC',
    );
    return List.generate(maps.length, (i) => Transaction.fromMap(maps[i]));
  }

  // Payer operations
  Future<Payer> createPayer(Payer payer) async {
    final db = await database;
    final id = await db.insert('payers', payer.toMap());
    return Payer(
      id: id,
      name: payer.name,
    );
  }

  Future<List<Payer>> getAllPayers() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'payers',
      orderBy: 'name ASC',
    );
    return List.generate(maps.length, (i) => Payer.fromMap(maps[i]));
  }

  Future<void> deletePayer(int id) async {
    final db = await database;
    await db.delete(
      'payers',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Category operations
  Future<Category> createCategory(Category category) async {
    final db = await database;
    final id = await db.insert('categories', category.toMap());
    return Category(
      id: id,
      name: category.name,
    );
  }

  Future<List<Category>> getAllCategories() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'categories',
      orderBy: 'name ASC',
    );
    return List.generate(maps.length, (i) => Category.fromMap(maps[i]));
  }

  Future<void> deleteCategory(int id) async {
    final db = await database;
    await db.delete(
      'categories',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> close() async {
    final db = await database;
    db.close();
  }

  Future<void> deleteDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'mosque_accounts.db');
    await databaseFactory.deleteDatabase(path);
    _database = null;
  }

  // Summary calculations
  Future<double> getTotalIncomeAllTime() async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0.0) as total 
      FROM transactions 
      WHERE type = ?
    ''', ['TransactionType.income']);
    return (result.first['total'] as num).toDouble();
  }

  Future<double> getTotalSavings() async {
    final db = await database;
    final income = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0.0) as total 
      FROM transactions 
      WHERE type = ?
    ''', ['TransactionType.income']);
    
    final deductions = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0.0) as total 
      FROM transactions 
      WHERE type = ?
    ''', ['TransactionType.deduction']);
    
    final totalIncome = (income.first['total'] as num).toDouble();
    final totalDeductions = (deductions.first['total'] as num).toDouble();
    return totalIncome - totalDeductions;
  }

  Future<double> getCurrentMonthSavings(int month, int year) async {
    final db = await database;
    final startDate = DateTime(year, month, 1).toIso8601String();
    final endDate = DateTime(year, month + 1, 0).toIso8601String();

    final income = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0.0) as total 
      FROM transactions 
      WHERE type = ? 
      AND date BETWEEN ? AND ?
    ''', ['TransactionType.income', startDate, endDate]);
    
    final deductions = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0.0) as total 
      FROM transactions 
      WHERE type = ? 
      AND date BETWEEN ? AND ?
    ''', ['TransactionType.deduction', startDate, endDate]);
    
    final monthlyIncome = (income.first['total'] as num).toDouble();
    final monthlyDeductions = (deductions.first['total'] as num).toDouble();
    return monthlyIncome - monthlyDeductions;
  }

  Future<double> getCurrentMonthIncome(int month, int year) async {
    final db = await database;
    final startDate = DateTime(year, month, 1).toIso8601String();
    final endDate = DateTime(year, month + 1, 0).toIso8601String();

    final result = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0.0) as total 
      FROM transactions 
      WHERE type = ? 
      AND date BETWEEN ? AND ?
    ''', ['TransactionType.income', startDate, endDate]);
    
    return (result.first['total'] as num).toDouble();
  }

  Future<double> getTotalDeductions() async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0.0) as total 
      FROM transactions 
      WHERE type = ?
    ''', ['TransactionType.deduction']);
    return (result.first['total'] as num).toDouble();
  }

  Future<double> getCurrentMonthDeductions(int month, int year) async {
    final db = await database;
    final startDate = DateTime(year, month, 1).toIso8601String();
    final endDate = DateTime(year, month + 1, 0).toIso8601String();

    final result = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0.0) as total 
      FROM transactions 
      WHERE type = ? 
      AND date BETWEEN ? AND ?
    ''', ['TransactionType.deduction', startDate, endDate]);
    
    return (result.first['total'] as num).toDouble();
  }
} 