import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logging/logging.dart' as logging;

class UserDatabaseService {
  static final UserDatabaseService _instance = UserDatabaseService._internal();
  static Database? _database;
  static final _logger = logging.Logger('UserDatabaseService');

  factory UserDatabaseService() => _instance;

  UserDatabaseService._internal();

  // Database keys
  static const String _usernameKey = 'username';
  static const String _userIdKey = 'user_id';
  static const String _initialDataSentKey = 'initial_data_sent';
  static const String _pointsKey = 'points';

  // Database table and column names
  static const String _userTable = 'user_data';
  static const String _columnId = 'id';
  static const String _columnName = 'name';
  static const String _columnPoints = 'points';
  static const String _columnLastUpdated = 'last_updated';

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'user_data.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $_userTable(
        $_columnId TEXT PRIMARY KEY,
        $_columnName TEXT,
        $_columnPoints INTEGER,
        $_columnLastUpdated TEXT
      )
    ''');
  }

  Future<String> getUsername() async {
    final prefs = await SharedPreferences.getInstance();
    String? username = prefs.getString(_usernameKey);
    return username ?? '';
  }

  Future<void> setUsername(String username) async {
    _logger.info('Setting username: $username');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_usernameKey, username);

    final userId = await getUserId();
    final db = await database;
    await db.update(
      _userTable,
      {
        _columnName: username,
        _columnLastUpdated: DateTime.now().toIso8601String(),
      },
      where: '$_columnId = ?',
      whereArgs: [userId],
    );
  }

  Future<int> getTotalPoints() async {
    final prefs = await SharedPreferences.getInstance();
    final points = prefs.getInt(_pointsKey) ?? 0;
    _logger.info('Current points: $points');
    return points;
  }

  Future<String> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    String? userId = prefs.getString(_userIdKey);
    return userId ?? _generateUserId();
  }

  String _generateUserId() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }

  Future<void> _createUserInDatabase(String userId) async {
    final db = await database;
    await db.insert(
      _userTable,
      {
        _columnId: userId,
        _columnName: await getUsername(),
        _columnPoints: 0,
        _columnLastUpdated: DateTime.now().toIso8601String(),
      },
    );
  }

  Future<bool> isInitialDataSent() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_initialDataSentKey) ?? false;
  }

  Future<void> setInitialDataSent(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_initialDataSentKey, value);
  }

  String _generateRandomUsername() {
    final adjectives = [
      'Happy',
      'Peaceful',
      'Kind',
      'Gentle',
      'Wise',
      'Patient',
      'Grateful',
      'Humble',
      'Generous',
      'Faithful'
    ];
    final nouns = [
      'Reader',
      'Learner',
      'Seeker',
      'Traveler',
      'Explorer',
      'Student',
      'Friend',
      'Guide',
      'Helper',
      'Soul'
    ];
    final random = DateTime.now().millisecondsSinceEpoch;
    final adjective = adjectives[random % adjectives.length];
    final noun = nouns[random % nouns.length];
    return '$adjective$noun${random % 1000}';
  }
}
