import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/surah.dart';
import 'dart:developer' as developer;

class QuranDatabaseService {
  static final QuranDatabaseService _instance =
      QuranDatabaseService._internal();
  static Database? _database;
  static String? _tableName; // Store the table name

  factory QuranDatabaseService() {
    return _instance;
  }

  QuranDatabaseService._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    try {
      // Get the path to the database file
      var databasesPath = await getDatabasesPath();
      var path = join(databasesPath, "quran.db");

      // Check if the database exists
      var exists = await databaseExists(path);

      if (!exists) {
        developer.log("Copying database from assets");

        // Make sure the parent directory exists
        try {
          await Directory(dirname(path)).create(recursive: true);
        } catch (e) {
          developer.log("Error creating directory: $e");
        }

        try {
          // Copy from assets - Note: fixed path format
          // Do not use join() for asset paths as it may use backslashes on Windows
          // Use forward slashes for asset paths which Flutter expects
          ByteData data = await rootBundle.load("assets/quran.sqlite");
          List<int> bytes =
              data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);

          developer.log("Asset loaded, size: ${bytes.length} bytes");
          if (bytes.isEmpty) {
            throw Exception("Asset data is empty");
          }

          // Write and flush the bytes
          await File(path).writeAsBytes(bytes, flush: true);
          developer.log("Database copied to: $path");
        } catch (e) {
          developer.log("Error copying database: $e");
          rethrow; // Rethrow to be caught by the calling function
        }
      } else {
        developer.log("Database already exists at: $path");
      }

      // Open the database
      final db = await openDatabase(
        path,
        readOnly: true, // We only need to read from it
      );

      // Check the database schema to find the right table
      await _discoverTableName(db);

      return db;
    } catch (e, stacktrace) {
      developer.log("Error initializing database: $e");
      developer.log("Stack trace: $stacktrace");
      rethrow; // Rethrow to be caught by the calling function
    }
  }

  /// Discovers the actual table name in the database
  Future<void> _discoverTableName(Database db) async {
    try {
      // Query for all tables in the database
      final List<Map<String, dynamic>> tables = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name;");

      developer
          .log("Available tables: ${tables.map((t) => t['name']).toList()}");

      // Check for common table names
      final possibleTableNames = [
        'quran',
        'Quran',
        'surahs',
        'Surahs',
        'surah',
        'Surah'
      ];

      // First check for exact matches in our possible table list
      for (var tableName in possibleTableNames) {
        final tableExists = tables.any((t) => t['name'] == tableName);
        if (tableExists) {
          _tableName = tableName;
          developer.log("Found table name: $_tableName");
          return;
        }
      }

      // If no exact match, take the first table that's not sqlite_* related
      for (var table in tables) {
        final name = table['name'] as String;
        if (!name.startsWith('sqlite_') && !name.startsWith('android_')) {
          _tableName = name;
          developer.log("Using first non-system table: $_tableName");
          return;
        }
      }

      // If we got here, we couldn't find a suitable table
      throw Exception("No suitable Quran table found in the database");
    } catch (e) {
      developer.log("Error discovering table name: $e");
      rethrow;
    }
  }

  Future<List<Surah>> getAllSurahs() async {
    try {
      final db = await database;

      // If table name hasn't been discovered yet
      if (_tableName == null) {
        await _discoverTableName(db);
      }

      if (_tableName == null) {
        throw Exception("Unable to find Quran table in database");
      }

      developer.log("Querying table: $_tableName");
      final List<Map<String, dynamic>> maps = await db.query(_tableName!);

      developer.log("Loaded ${maps.length} surahs from database");

      // Convert the List<Map<String, dynamic>> into a List<Surah>
      return List.generate(maps.length, (i) {
        return Surah.fromMap(maps[i]);
      });
    } catch (e, stacktrace) {
      developer.log("Error getting all surahs: $e");
      developer.log("Stack trace: $stacktrace");
      rethrow; // Rethrow to be caught by the calling function
    }
  }

  Future<Surah?> getSurahById(int id) async {
    try {
      final db = await database;

      // If table name hasn't been discovered yet
      if (_tableName == null) {
        await _discoverTableName(db);
      }

      if (_tableName == null) {
        throw Exception("Unable to find Quran table in database");
      }

      final List<Map<String, dynamic>> maps = await db.query(
        _tableName!,
        where: 'id = ?',
        whereArgs: [id],
      );

      if (maps.isNotEmpty) {
        return Surah.fromMap(maps.first);
      }
      return null;
    } catch (e) {
      developer.log("Error getting surah by id: $e");
      rethrow;
    }
  }

  Future<List<Surah>> searchSurahs(String query) async {
    try {
      final db = await database;

      // If table name hasn't been discovered yet
      if (_tableName == null) {
        await _discoverTableName(db);
      }

      if (_tableName == null) {
        throw Exception("Unable to find Quran table in database");
      }

      final List<Map<String, dynamic>> maps = await db.query(
        _tableName!,
        where: 'name_pron_en LIKE ? OR name_ar LIKE ?',
        whereArgs: ['%$query%', '%$query%'],
      );

      return List.generate(maps.length, (i) {
        return Surah.fromMap(maps[i]);
      });
    } catch (e) {
      developer.log("Error searching surahs: $e");
      rethrow;
    }
  }

  /// Get surahs within a specific ID range for pagination
  Future<List<Surah>> getSurahsByRange(int startId, int endId) async {
    try {
      final db = await database;

      // If table name hasn't been discovered yet
      if (_tableName == null) {
        await _discoverTableName(db);
      }

      if (_tableName == null) {
        throw Exception("Unable to find Quran table in database");
      }

      // Query with range
      final List<Map<String, dynamic>> maps = await db.query(
        _tableName!,
        where: 'id BETWEEN ? AND ?',
        whereArgs: [startId, endId],
        orderBy: 'id ASC',
      );

      developer.log("Loaded ${maps.length} surahs from range $startId-$endId");

      return List.generate(maps.length, (i) {
        return Surah.fromMap(maps[i]);
      });
    } catch (e) {
      developer.log("Error getting surahs by range: $e");
      rethrow;
    }
  }

  /// Method to inspect database schema
  Future<void> logDatabaseSchema() async {
    try {
      final db = await database;

      // Get all tables
      final List<Map<String, dynamic>> tables = await db
          .rawQuery("SELECT name FROM sqlite_master WHERE type='table';");

      developer
          .log("Database tables: ${tables.map((t) => t['name']).toList()}");

      // For each table, get its columns
      for (var table in tables) {
        final tableName = table['name'] as String;
        if (!tableName.startsWith('sqlite_')) {
          final List<Map<String, dynamic>> columns =
              await db.rawQuery("PRAGMA table_info($tableName);");

          developer.log(
              "Table '$tableName' columns: ${columns.map((c) => "${c['name']} (${c['type']})").toList()}");

          // Get a sample row to see the data
          final List<Map<String, dynamic>> sampleRow = await db.query(
            tableName,
            limit: 1,
          );

          if (sampleRow.isNotEmpty) {
            developer.log("Sample data from '$tableName': ${sampleRow.first}");
          }
        }
      }
    } catch (e) {
      developer.log("Error logging schema: $e");
    }
  }
}
