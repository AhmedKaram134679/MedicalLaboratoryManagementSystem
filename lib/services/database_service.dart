import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'user_service.dart';

class DatabaseService {
  static const int _databaseVersion = 19;
  static final DatabaseService _instance = DatabaseService._internal();
  static Database? _database;

  factory DatabaseService() => _instance;

  DatabaseService._internal();

  @visibleForTesting
  static void setDatabaseForTesting(Database? testDb) {
    _database = testDb;
    _dbOpenCompleter = null;
  }

  static Completer<Database>? _dbOpenCompleter;

  Future<Database> get database async {
    if (_database != null) return _database!;
    if (_dbOpenCompleter != null) return _dbOpenCompleter!.future;

    _dbOpenCompleter = Completer<Database>();
    try {
      _database = await _initDatabase();
      _dbOpenCompleter!.complete(_database);
    } catch (e) {
      _dbOpenCompleter!.completeError(e);
      _dbOpenCompleter = null; // Reset to allow retry
      rethrow;
    }
    return _dbOpenCompleter!.future;
  }

  /// Initiates database opening in background without waiting for result.
  void preWarm() async {
    try {
      await database;
    } catch (e) {
      debugPrint('DB Pre-warm error: $e');
    }
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
      _dbOpenCompleter = null;
    }
  }

  Future<Database> _initDatabase() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, 'mlms_database.db');

    Database db = await openDatabase(
      path,
      version: _databaseVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA journal_mode=WAL;');
        await db.execute('PRAGMA busy_timeout=5000;');
        await db.execute('PRAGMA foreign_keys = ON;');
      },
      onCreate: onCreate,
      onUpgrade: onUpgrade,
    );

    return db;
  }

  Future<void> _runMigrationStep(
    String stepName,
    Future<void> Function() action, {
    bool isCritical = false,
  }) async {
    try {
      await action();
      debugPrint('[DatabaseMigration] Successfully executed: $stepName');
    } catch (e, stack) {
      debugPrint('[DatabaseMigration ERROR] Failure during $stepName: $e\n$stack');
      if (isCritical) {
        throw Exception('Critical migration failure at $stepName: $e');
      }
    }
  }

  Future onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _runMigrationStep('v2 base tables and sample data', () async {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS test_results (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            patient_test_id INTEGER NOT NULL,
            field_name TEXT NOT NULL,
            result_value TEXT,
            unit TEXT,
            normal_range TEXT,
            is_abnormal INTEGER DEFAULT 0,
            FOREIGN KEY (patient_test_id) REFERENCES patient_tests (id)
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS inventory (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            item_name TEXT NOT NULL,
            quantity REAL DEFAULT 0,
            unit TEXT,
            min_threshold REAL DEFAULT 5,
            last_updated TEXT
          )
        ''');
        await db.insert('users', {
          'username': 'admin',
          'password': UserService.hashPassword('admin', salt: 'admin'),
          'role': 'admin',
          'full_name': 'مدير النظام',
          'force_password_change': 1,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
        await _insertSampleData(db);
      });
    }

    if (oldVersion < 3) {
      await _runMigrationStep('v3 patients file_no', () async {
        await db.execute('ALTER TABLE patients ADD COLUMN file_no TEXT');
      });
      await _runMigrationStep('v3 patient_tests sort_order', () async {
        await db.execute(
          'ALTER TABLE patient_tests ADD COLUMN sort_order INTEGER DEFAULT 0',
        );
      });
    }

    if (oldVersion < 4) {
      await _runMigrationStep('v4 audit_logs & app_settings', () async {
        await db.execute('''
          CREATE TABLE audit_logs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_name TEXT,
            action TEXT NOT NULL,
            data_type TEXT,
            timestamp TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE app_settings (
            key TEXT PRIMARY KEY,
            value TEXT
          )
        ''');
      });
    }

    if (oldVersion < 5) {
      await _runMigrationStep('v5 tests_metadata is_active', () async {
        await db.execute(
          'ALTER TABLE tests_metadata ADD COLUMN is_active INTEGER DEFAULT 1',
        );
      });
    }

    if (oldVersion < 6) {
      await _runMigrationStep('v6 patient_tests comment', () async {
        await db.execute('ALTER TABLE patient_tests ADD COLUMN comment TEXT');
      });
    }

    if (oldVersion < 7) {
      await _runMigrationStep('v7 inventory category, expiry_date, notes', () async {
        await db.execute('ALTER TABLE inventory ADD COLUMN category TEXT');
        await db.execute('ALTER TABLE inventory ADD COLUMN expiry_date TEXT');
        await db.execute('ALTER TABLE inventory ADD COLUMN notes TEXT');

        await db.execute('''
          CREATE TABLE test_inventory_consumption (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            test_metadata_id INTEGER NOT NULL,
            inventory_item_id INTEGER NOT NULL,
            quantity_consumed REAL NOT NULL,
            FOREIGN KEY (test_metadata_id) REFERENCES tests_metadata (id),
            FOREIGN KEY (inventory_item_id) REFERENCES inventory (id)
          )
        ''');

        await db.execute('ALTER TABLE audit_logs ADD COLUMN details TEXT');
      });
    }

    if (oldVersion < 8) {
      await _runMigrationStep('v8 patients notes', () async {
        await db.execute('ALTER TABLE patients ADD COLUMN notes TEXT');
      });
    }

    if (oldVersion < 9) {
      await _runMigrationStep('v9 admin_requests', () async {
        await db.execute('''
          CREATE TABLE admin_requests (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            username TEXT NOT NULL,
            request_type TEXT NOT NULL,
            details TEXT,
            status TEXT DEFAULT 'Pending',
            created_at TEXT NOT NULL
          )
        ''');
      });
    }

    if (oldVersion < 11) {
      await _runMigrationStep('v11 reports table', () async {
        await db.execute('''
          CREATE TABLE reports (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            type TEXT NOT NULL,
            generated_by TEXT,
            generated_at TEXT NOT NULL,
            status TEXT NOT NULL,
            metadata TEXT,
            columns TEXT,
            data TEXT,
            item_count INTEGER,
            notes TEXT
          )
        ''');
      });
    }

    if (oldVersion < 12) {
      await _runMigrationStep('v12 backup_logs table', () async {
        await db.execute('''
          CREATE TABLE backup_logs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp TEXT NOT NULL,
            status TEXT NOT NULL,
            error_message TEXT,
            target_folder TEXT,
            trigger_type TEXT NOT NULL
          )
        ''');
      });
    }

    if (oldVersion < 14) {
      await _runMigrationStep('v14 test_inventory_usage table', () async {
        await db.execute('''
          CREATE TABLE test_inventory_usage (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            test_id INTEGER NOT NULL,
            inventory_id INTEGER NOT NULL,
            quantity REAL NOT NULL,
            FOREIGN KEY (test_id) REFERENCES tests_metadata (id),
            FOREIGN KEY (inventory_id) REFERENCES inventory (id)
          )
        ''');

        final tables = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='test_inventory_consumption'",
        );
        if (tables.isNotEmpty) {
          await db.execute('''
            INSERT INTO test_inventory_usage (test_id, inventory_id, quantity)
            SELECT test_metadata_id, inventory_item_id, quantity_consumed
            FROM test_inventory_consumption
          ''');
          await db.execute('DROP TABLE test_inventory_consumption');
        }
      });
    }

    if (oldVersion < 15) {
      await _runMigrationStep('v15 updated_at timestamp columns', () async {
        await db.execute(
          'ALTER TABLE patient_tests ADD COLUMN updated_at TEXT',
        );
        await db.execute('ALTER TABLE patients ADD COLUMN updated_at TEXT');

        await db.execute('UPDATE patient_tests SET updated_at = created_at');
        await db.execute('UPDATE patients SET updated_at = created_at');
      });
    }

    if (oldVersion < 16) {
      await _runMigrationStep('v16 performance indexes', () async {
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_patients_created_at ON patients (created_at)',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_pt_status_patient ON patient_tests (status, patient_id)',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_pt_created_at ON patient_tests (created_at)',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_tr_patient_test_id ON test_results (patient_test_id)',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_inv_qty_expiry ON inventory (quantity, expiry_date)',
        );
      });
    }

    if (oldVersion < 17) {
      await _runMigrationStep('v17 test_inventory_usage IF NOT EXISTS', () async {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS test_inventory_usage (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            test_id INTEGER NOT NULL,
            inventory_id INTEGER NOT NULL,
            quantity REAL NOT NULL,
            FOREIGN KEY (test_id) REFERENCES tests_metadata (id),
            FOREIGN KEY (inventory_id) REFERENCES inventory (id)
          )
        ''');

        final tables = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='test_inventory_consumption'",
        );
        if (tables.isNotEmpty) {
          await db.execute('''
            INSERT INTO test_inventory_usage (test_id, inventory_id, quantity)
            SELECT test_metadata_id, inventory_item_id, quantity_consumed
            FROM test_inventory_consumption
          ''');
          await db.execute('DROP TABLE test_inventory_consumption');
        }
      });

      await _runMigrationStep('v17 tests_metadata template_type', () async {
        await db.execute('ALTER TABLE tests_metadata ADD COLUMN template_type TEXT');

        await db.rawUpdate('''
          UPDATE tests_metadata 
          SET template_type = CASE 
            WHEN LOWER(name) LIKE '%urine%' OR LOWER(name) LIKE '%بول%' THEN 'urine'
            WHEN LOWER(name) LIKE '%stool%' OR LOWER(name) LIKE '%براز%' THEN 'stool'
            WHEN LOWER(name) LIKE '%vitamin d%' OR LOWER(name) LIKE '%فيتامين د%' OR LOWER(name) LIKE '%vit d%' THEN 'vitamin_d'
            ELSE 'generic'
          END
        ''');
      });
    }

    if (oldVersion < 18) {
      await _runMigrationStep('v18 force_password_change column', () async {
        await db.execute(
          'ALTER TABLE users ADD COLUMN force_password_change INTEGER DEFAULT 0',
        );
      }, isCritical: true);

      await _runMigrationStep('v18 password hash migration', () async {
        final userList = await db.query('users');
        for (var u in userList) {
          final String username = (u['username'] as String?) ?? '';
          final String pwd = (u['password'] as String?) ?? '';
          final bool isAlreadyHashed = pwd.startsWith('pbkdf2_') || (pwd.length == 64 && RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(pwd));
          if (pwd.isNotEmpty && !isAlreadyHashed) {
            final hashed = UserService.hashPassword(pwd, salt: username);
            await db.update(
              'users',
              {'password': hashed},
              where: 'id = ?',
              whereArgs: [u['id']],
            );
          }
        }
      }, isCritical: true);

      await _runMigrationStep('v18 normalize stool test result field names', () async {
        await db.rawUpdate('''
          UPDATE test_results
          SET field_name = 'Pus cells'
          WHERE LOWER(field_name) = 'pus cells'
        ''');
        await db.rawUpdate('''
          UPDATE test_results
          SET field_name = 'RBCs'
          WHERE LOWER(field_name) = 'r.b.cs' OR LOWER(field_name) = 'rbcs'
        ''');
        await db.rawUpdate('''
          UPDATE test_results
          SET field_name = 'Starch granules'
          WHERE LOWER(field_name) = 'starch granules'
        ''');
        await db.rawUpdate('''
          UPDATE test_results
          SET field_name = 'Fat globules'
          WHERE LOWER(field_name) = 'fat globules'
        ''');
        await db.rawUpdate('''
          UPDATE test_results
          SET field_name = 'Vegetable cells'
          WHERE LOWER(field_name) = 'vegetable cells'
        ''');
        await db.rawUpdate('''
          UPDATE test_results
          SET field_name = 'Muscle fibers'
          WHERE LOWER(field_name) = 'muscle fibers' OR LOWER(field_name) = 'muscle fibres'
        ''');
      }, isCritical: true);
    }

    if (oldVersion < 19) {
      await _runMigrationStep('v19 patients address column', () async {
        await db.execute('ALTER TABLE patients ADD COLUMN address TEXT');
      }, isCritical: true);
    }
  }

  Future onCreate(Database db, int version) async {
    // Users table
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT UNIQUE NOT NULL,
        password TEXT NOT NULL,
        role TEXT NOT NULL,
        full_name TEXT,
        force_password_change INTEGER DEFAULT 0
      )
    ''');

    // Patients table
    await db.execute('''
      CREATE TABLE patients (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        daily_id INTEGER NOT NULL,
        file_no TEXT,
        name TEXT NOT NULL,
        age INTEGER NOT NULL,
        gender TEXT NOT NULL,
        phone TEXT,
        address TEXT,
        whatsapp INTEGER DEFAULT 0,
        doctor_id INTEGER,
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT
      )
    ''');

    // Doctors table
    await db.execute('''
      CREATE TABLE doctors (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        specialization TEXT
      )
    ''');

    // Tests metadata table
    await db.execute('''
      CREATE TABLE tests_metadata (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        price REAL NOT NULL,
        department TEXT,
        normal_range_info TEXT,
        is_active INTEGER DEFAULT 1,
        template_type TEXT DEFAULT 'generic'
      )
    ''');

    // Test Fields table (for specific items in a test, e.g., WBC, RBC in CBC)
    await db.execute('''
      CREATE TABLE test_fields (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        test_metadata_id INTEGER NOT NULL,
        field_name TEXT NOT NULL,
        unit TEXT,
        default_range TEXT,
        FOREIGN KEY (test_metadata_id) REFERENCES tests_metadata (id)
      )
    ''');

    // Patient Tests table
    await db.execute('''
      CREATE TABLE patient_tests (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        patient_id INTEGER NOT NULL,
        test_id INTEGER NOT NULL,
        sort_order INTEGER DEFAULT 0,
        total_price REAL NOT NULL,
        discount REAL DEFAULT 0,
        paid REAL DEFAULT 0,
        status TEXT DEFAULT 'Pending',
        comment TEXT,
        inventory_deducted INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT,
        FOREIGN KEY (patient_id) REFERENCES patients (id),
        FOREIGN KEY (test_id) REFERENCES tests_metadata (id)
      )
    ''');

    // Audit Logs table
    await db.execute('''
      CREATE TABLE audit_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_name TEXT,
        action TEXT NOT NULL,
        data_type TEXT,
        details TEXT,
        timestamp TEXT NOT NULL
      )
    ''');

    // App Settings table
    await db.execute('''
      CREATE TABLE app_settings (
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');

    // Test Results table
    await db.execute('''
      CREATE TABLE test_results (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        patient_test_id INTEGER NOT NULL,
        field_name TEXT NOT NULL,
        result_value TEXT,
        unit TEXT,
        normal_range TEXT,
        is_abnormal INTEGER DEFAULT 0,
        FOREIGN KEY (patient_test_id) REFERENCES patient_tests (id)
      )
    ''');

    // Inventory table
    await db.execute('''
      CREATE TABLE inventory (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        item_name TEXT NOT NULL,
        category TEXT,
        quantity REAL DEFAULT 0,
        unit TEXT,
        min_threshold REAL DEFAULT 5,
        expiry_date TEXT,
        notes TEXT,
        last_updated TEXT
      )
    ''');

    // Test Inventory Usage mapping
    await db.execute('''
      CREATE TABLE test_inventory_usage (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        test_id INTEGER NOT NULL,
        inventory_id INTEGER NOT NULL,
        quantity REAL NOT NULL,
        FOREIGN KEY (test_id) REFERENCES tests_metadata (id),
        FOREIGN KEY (inventory_id) REFERENCES inventory (id)
      )
    ''');

    // Admin Requests table
    await db.execute('''
      CREATE TABLE admin_requests (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT NOT NULL,
        request_type TEXT NOT NULL,
        details TEXT,
        status TEXT DEFAULT 'Pending',
        created_at TEXT NOT NULL
      )
    ''');

    // Reports table
    await db.execute('''
      CREATE TABLE reports (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        type TEXT NOT NULL,
        generated_by TEXT,
        generated_at TEXT NOT NULL,
        status TEXT NOT NULL,
        metadata TEXT,
        columns TEXT,
        data TEXT,
        item_count INTEGER,
        notes TEXT
      )
    ''');

    // Backup Logs table
    await db.execute('''
      CREATE TABLE backup_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        timestamp TEXT NOT NULL,
        status TEXT NOT NULL,
        error_message TEXT,
        target_folder TEXT,
        trigger_type TEXT NOT NULL
      )
    ''');

    // Insert Default Admin with forced password change on first login
    await db.insert('users', {
      'username': 'admin',
      'password': UserService.hashPassword('admin', salt: 'admin'),
      'role': 'admin',
      'full_name': 'مدير النظام',
      'force_password_change': 1,
    });

    // Sample Data: Tests, Fields & Inventory
    await _insertSampleData(db);

    // Create Indexes
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_patients_created_at ON patients (created_at)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_pt_status_patient ON patient_tests (status, patient_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_pt_created_at ON patient_tests (created_at)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_tr_patient_test_id ON test_results (patient_test_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_inv_qty_expiry ON inventory (quantity, expiry_date)',
    );
  }

  Future<void> _insertSampleData(Database db) async {
    // Clean sample data: do not insert dummy tests or inventory
  }
}
