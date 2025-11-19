// Dart imports:
import 'dart:io';

// Package imports:
import 'package:sembast/sembast_io.dart';

/// Connects to a Sembast database and provides access to stores
class DatabaseConnector {
  Database? _database;
  final String dbPath;

  DatabaseConnector(this.dbPath);

  /// Open the database connection
  Future<void> open() async {
    if (_database != null) return;
    
    final file = File(dbPath);
    if (!file.existsSync()) {
      throw Exception('Database file not found: $dbPath');
    }
    
    _database = await databaseFactoryIo.openDatabase(dbPath);
  }

  /// Close the database connection
  Future<void> close() async {
    await _database?.close();
    _database = null;
  }

  /// Discover all store names in the database
  /// 
  /// Scans the database file to extract store names.
  /// Sembast stores data in a line-delimited JSON format where each line
  /// contains a record with a "store" field indicating which store it belongs to.
  /// Returns a list of unique store names that exist in the database.
  Future<List<String>> discoverStores() async {
    await open();
    final discoveredStores = <String>{};
    
    try {
      // Read the database file and extract store names
      // Sembast format: each line is a JSON object like:
      // {"key":"...","store":"store_name","value":{...}}
      final file = File(dbPath);
      if (!file.existsSync()) {
        return [];
      }
      
      // Read file line by line to find store names
      // Store names appear in the format: "store":"store_name"
      final lines = await file.readAsLines();
      final storeNamePattern = RegExp(r'"store"\s*:\s*"([^"]+)"');
      
      for (final line in lines) {
        // Skip version/metadata lines
        if (line.trim().isEmpty || !line.contains('"store"')) {
          continue;
        }
        
        final match = storeNamePattern.firstMatch(line);
        if (match != null && match.groupCount >= 1) {
          final storeName = match.group(1);
          if (storeName != null && storeName.isNotEmpty) {
            discoveredStores.add(storeName);
          }
        }
      }
      
    } catch (e) {
      // If file reading fails, return empty list
      // Users can still add stores manually
    }
    
    final result = discoveredStores.toList();
    result.sort();
    return result;
  }
  
  /// Discover store names by checking if they exist and have data
  /// 
  /// [storeNamesToCheck] - List of store names to check.
  /// 
  /// Example:
  /// ```dart
  /// final stores = await connector.discoverStoresByChecking(
  ///   storeNamesToCheck: ['users', 'products', 'orders'],
  /// );
  /// ```
  Future<List<String>> discoverStoresByChecking({
    required List<String> storeNamesToCheck,
  }) async {
    await open();
    final discoveredStores = <String>[];
    
    // Check stores in parallel for better performance
    final futures = storeNamesToCheck.map((storeName) async {
      if (await storeExists(storeName)) {
        return storeName;
      }
      return null;
    });
    
    final results = await Future.wait(futures);
    for (final result in results) {
      if (result != null) {
        discoveredStores.add(result);
      }
    }
    
    // Sort alphabetically
    discoveredStores.sort();
    
    return discoveredStores;
  }

  /// Get all store names in the database
  /// Note: Sembast doesn't expose store names directly, so this returns
  /// a list of common store patterns. Users should specify store names manually.
  @Deprecated('Use discoverStores() instead')
  Future<List<String>> getStoreNames() async {
    return await discoverStores();
  }
  
  /// Try to access a store and return true if it exists and has data
  Future<bool> storeExists(String storeName) async {
    try {
      await open();
      final store = StoreRef<String, Map<String, dynamic>>(storeName);
      final count = await store.count(_database!);
      return count > 0;
    } catch (e) {
      return false;
    }
  }

  /// Get all records from a specific store
  Future<List<Map<String, dynamic>>> getStoreRecords(String storeName) async {
    await open();
    final store = StoreRef<String, Map<String, dynamic>>(storeName);
    final records = await store.find(_database!);
    
    return records.map((record) {
      final data = Map<String, dynamic>.from(record.value);
      data['_key'] = record.key;
      return data;
    }).toList();
  }

  /// Get limited records from a specific store (first N records)
  Future<List<Map<String, dynamic>>> getStoreRecordsLimited(String storeName, {int limit = 1000}) async {
    await open();
    final store = StoreRef<String, Map<String, dynamic>>(storeName);
    final records = await store.find(_database!, finder: Finder(limit: limit));
    
    return records.map((record) {
      final data = Map<String, dynamic>.from(record.value);
      data['_key'] = record.key;
      return data;
    }).toList();
  }

  /// Get a specific record by key
  Future<Map<String, dynamic>?> getRecord(String storeName, String key) async {
    await open();
    final store = StoreRef<String, Map<String, dynamic>>(storeName);
    final record = await store.record(key).get(_database!);
    
    if (record == null) return null;
    
    final data = Map<String, dynamic>.from(record);
    data['_key'] = key;
    return data;
  }


  Database? get database => _database;
}

