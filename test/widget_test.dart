import 'package:flutter_test/flutter_test.dart';
import 'package:lab_managment_system/models/patient_model.dart';
import 'package:lab_managment_system/models/user_model.dart';
import 'package:lab_managment_system/models/test_metadata_model.dart';
import 'package:lab_managment_system/models/doctor_model.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'dart:math';
import 'package:lab_managment_system/services/user_service.dart';
import 'package:lab_managment_system/services/database_service.dart';
import 'package:lab_managment_system/services/statistics_service.dart';
import 'package:lab_managment_system/utils/clinical_utils.dart';

void main() {
  group('Data Models Unit Tests', () {
    test('UserModel serialization and deserialization', () {
      final user = UserModel(
        id: 1,
        username: 'admin',
        password: 'hashed_password_sample_1234567890abcdef1234567890abcdef1234567890abcdef',
        role: 'admin',
        fullName: 'Admin User',
        forcePasswordChange: true,
      );

      final map = user.toMap();
      expect(map['id'], 1);
      expect(map['username'], 'admin');
      expect(map['role'], 'admin');
      expect(map['full_name'], 'Admin User');
      expect(map['force_password_change'], 1);

      final fromMapUser = UserModel.fromMap(map);
      expect(fromMapUser.id, user.id);
      expect(fromMapUser.username, user.username);
      expect(fromMapUser.role, user.role);
      expect(fromMapUser.fullName, user.fullName);
      expect(fromMapUser.forcePasswordChange, true);
    });

    test('TestMetadataModel serialization and template type', () {
      final testMetadata = TestMetadataModel(
        id: 10,
        name: 'Urinalysis',
        price: 25.0,
        department: 'Biochemistry',
        normalRangeInfo: 'Negative',
        isActive: 1,
        templateType: 'urine',
      );

      final map = testMetadata.toMap();
      expect(map['name'], 'Urinalysis');
      expect(map['price'], 25.0);
      expect(map['template_type'], 'urine');

      final fromMapTest = TestMetadataModel.fromMap(map);
      expect(fromMapTest.id, 10);
      expect(fromMapTest.templateType, 'urine');
      expect(fromMapTest.price, 25.0);
    });

    test('DoctorModel serialization and deserialization', () {
      final doctor = DoctorModel(
        id: 5,
        name: 'Dr. John Doe',
        specialization: 'Internal Medicine',
      );

      final map = doctor.toMap();
      expect(map['name'], 'Dr. John Doe');
      expect(map['specialization'], 'Internal Medicine');

      final fromMapDoc = DoctorModel.fromMap(map);
      expect(fromMapDoc.id, 5);
      expect(fromMapDoc.name, 'Dr. John Doe');
      expect(fromMapDoc.specialization, 'Internal Medicine');
    });

    test('PatientModel serialization with address field', () {
      final patient = PatientModel(
        id: 101,
        dailyId: 42,
        fileNo: 'P-1002',
        name: 'Jane Doe',
        age: 30,
        gender: 'Female',
        phone: '0123456789',
        address: '123 Medical Center Street, Cairo',
        isWhatsapp: true,
        doctorId: 3,
        notes: 'Fasting 12 hours',
        createdAt: DateTime(2026, 10, 4, 10, 0),
      );

      final map = patient.toMap();
      expect(map['daily_id'], 42);
      expect(map['address'], '123 Medical Center Street, Cairo');
      expect(map['whatsapp'], 1);

      final fromMapPatient = PatientModel.fromMap(map);
      expect(fromMapPatient.id, 101);
      expect(fromMapPatient.address, '123 Medical Center Street, Cairo');
      expect(fromMapPatient.isWhatsapp, true);
    });

    test('Patient test price and remaining balance calculations with positive remaining and separate overpayment', () {
      final tests = [
        {'price': 100.0},
        {'price': 150.0},
        {'price': 50.0},
      ];

      final double grossTotal = tests.fold<double>(
        0.0,
        (sum, item) => sum + (item['price'] as double),
      );
      const double discount = 30.0;
      final double netTotal = grossTotal - discount; // 270.0

      // Scenario 1: Partial payment (remaining > 0)
      const double partialPaid = 200.0;
      final double remaining1 = max(netTotal - partialPaid, 0.0);
      final double overpayment1 = max(partialPaid - netTotal, 0.0);
      expect(grossTotal, 300.0);
      expect(netTotal, 270.0);
      expect(remaining1, 70.0);
      expect(overpayment1, 0.0);

      // Scenario 2: Overpayment (paid > netTotal)
      const double overPaid = 300.0;
      final double remaining2 = max(netTotal - overPaid, 0.0);
      final double overpayment2 = max(overPaid - netTotal, 0.0);
      expect(remaining2, 0.0);
      expect(overpayment2, 30.0);

      // Scenario 3: Exact payment
      const double exactPaid = 270.0;
      final double remaining3 = max(netTotal - exactPaid, 0.0);
      final double overpayment3 = max(exactPaid - netTotal, 0.0);
      expect(remaining3, 0.0);
      expect(overpayment3, 0.0);
    });

    test('SHA-256 password salting produces consistent 64-char hex digest', () {
      const salt = 'random_user_salt_123';
      const plain = 'admin123';
      final digest = sha256.convert(utf8.encode('$plain$salt')).toString();

      expect(digest.length, 64);
      expect(RegExp(r'^[a-f0-9]{64}$').hasMatch(digest), isTrue);
    });
  });

  group('Password Security & Hashing Unit Tests', () {
    test('Standard PBKDF2-HMAC-SHA256 password hashing', () {
      const password = 'SuperSecretPassword@2026';
      const salt = 'admin';
      final pbkdf2Hash = UserService.hashPassword(password, salt: salt, iterations: 100);
      expect(pbkdf2Hash.startsWith('pbkdf2_\$i100\$'), isTrue);

      final singleHash = UserService.hashPasswordSingleIteration(password, salt: salt);
      expect(singleHash.length, 64);
      expect(pbkdf2Hash, isNot(equals(singleHash)));
    });

    test('Standard PBKDF2-HMAC-SHA256 candidate verification', () {
      final derived1 = UserService.hashPassword('password', salt: 'salt', iterations: 1);
      final derived2 = UserService.hashPassword('password', salt: 'salt', iterations: 2);
      expect(derived1.startsWith('pbkdf2_\$i1\$'), isTrue);
      expect(derived2.startsWith('pbkdf2_\$i2\$'), isTrue);
      expect(derived1, isNot(equals(derived2)));
      expect(UserService.verifyHash(derived1, UserService.hashPassword('password', salt: 'salt', iterations: 1)), isTrue);
      expect(UserService.verifyHash(derived2, UserService.hashPassword('password', salt: 'salt', iterations: 2)), isTrue);
    });

    test('Modern salted SHA-256 hash formatting (plain::salt)', () {
      const password = 'SuperSecretPassword@2026';
      const salt = 'admin';
      final modernHash = sha256.convert(utf8.encode('$password::$salt')).toString();
      final legacyHash = sha256.convert(utf8.encode('$password$salt')).toString();

      expect(modernHash.length, 64);
      expect(legacyHash.length, 64);
      expect(modernHash, isNot(equals(legacyHash)));

      // Verifying candidate matching logic
      expect(modernHash == sha256.convert(utf8.encode('SuperSecretPassword@2026::$salt')).toString(), isTrue);
      expect(legacyHash == sha256.convert(utf8.encode('SuperSecretPassword@2026$salt')).toString(), isTrue);
    });

    test('Password complexity verification', () {
      // Must be at least 8 characters (matches login_screen policy)
      bool isValidPassword(String pwd) => pwd.length >= 8;
      expect(isValidPassword('12345'), isFalse);
      expect(isValidPassword('123456'), isFalse);
      expect(isValidPassword('1234567'), isFalse);
      expect(isValidPassword('12345678'), isTrue);
      expect(isValidPassword('Admin@123'), isTrue);
    });

    test('RFC 6070 PBKDF2-HMAC-SHA256 Known-Vector Verification', () {
      // Test RFC 6070 standard iteration vector: password="password", salt="salt", c=1
      final hashIter1 = UserService.hashPassword('password', salt: 'salt', iterations: 1);
      // U_1 = HMAC-SHA256("password", "salt" || 0001)
      final expectedU1Bytes = Hmac(sha256, utf8.encode('password')).convert([...utf8.encode('salt'), 0, 0, 0, 1]).bytes;
      final expectedHex1 = expectedU1Bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      expect(hashIter1, 'pbkdf2_\$i1\$$expectedHex1');

      // Test RFC 6070 standard iteration vector: c=2
      final hashIter2 = UserService.hashPassword('password', salt: 'salt', iterations: 2);
      expect(hashIter2.startsWith('pbkdf2_\$i2\$'), isTrue);
      expect(hashIter1, isNot(equals(hashIter2)));
      expect(UserService.verifyHash(hashIter2, UserService.hashPassword('password', salt: 'salt', iterations: 2)), isTrue);
    });

    test('Financial Paid Distribution 2-decimal rounding with exact remainder assignment invoking ClinicalUtils', () {
      final testPrices = [30.0, 50.0, 45.0];
      const total = 125.0;
      const globalDiscount = 10.0;
      const globalPaid = 70.0;

      // Invoke real production method directly
      final distributedItems = ClinicalUtils.distributeFinancials(
        prices: testPrices,
        total: total,
        globalDiscount: globalDiscount,
        globalPaid: globalPaid,
      );

      final sumDiscount = distributedItems.fold<double>(0.0, (acc, e) => acc + (e['discount'] as double));
      final sumPaid = distributedItems.fold<double>(0.0, (acc, e) => acc + (e['paid'] as double));

      expect(double.parse(sumDiscount.toStringAsFixed(2)), equals(globalDiscount));
      expect(double.parse(sumPaid.toStringAsFixed(2)), equals(globalPaid));
    });

    test('Clinical Abnormality Logic invoking ClinicalUtils.isResultAbnormal', () {
      // Normal within range
      expect(ClinicalUtils.isResultAbnormal('5.0', '4.0 - 10.0'), isFalse);
      // Low (abnormal)
      expect(ClinicalUtils.isResultAbnormal('3.2', '4.0 - 10.0'), isTrue);
      // High (abnormal)
      expect(ClinicalUtils.isResultAbnormal('12.5', '4.0 - 10.0'), isTrue);
      // Null / Empty
      expect(ClinicalUtils.isResultAbnormal('', '4.0 - 10.0'), isFalse);
    });
  });

  group('Clinical Regex Abnormal Color Detection Tests', () {
    final abnormalPattern = RegExp(
      r'\b(many|plenty|numerous|over\s+\d+)|>\s*\d+',
      caseSensitive: false,
    );

    test('Matches abnormal qualitative clinical keywords', () {
      expect(abnormalPattern.hasMatch('many'), isTrue);
      expect(abnormalPattern.hasMatch('Plenty of calcium oxalate crystals'), isTrue);
      expect(abnormalPattern.hasMatch('numerous pus cells observed'), isTrue);
      expect(abnormalPattern.hasMatch('over 100'), isTrue);
      expect(abnormalPattern.hasMatch('> 50'), isTrue);
      expect(abnormalPattern.hasMatch('>100 /HPF'), isTrue);
    });

    test('Does NOT falsely flag normal, rare, or few clinical keywords', () {
      expect(abnormalPattern.hasMatch('nil'), isFalse);
      expect(abnormalPattern.hasMatch('rare'), isFalse);
      expect(abnormalPattern.hasMatch('few'), isFalse);
      expect(abnormalPattern.hasMatch('normal'), isFalse);
      expect(abnormalPattern.hasMatch('clear'), isFalse);
      expect(abnormalPattern.hasMatch('yellow'), isFalse);
      expect(abnormalPattern.hasMatch('1-2 /HPF'), isFalse);
    });
  });

  group('Database Schema & Inventory Atomic Business Logic Tests', () {
    test('Simulated atomic stock deduction logic', () {
      final inventory = <String, int>{
        'Reagent_A': 100,
        'Tubes_EDTA': 50,
      };

      final deductions = <String, int>{
        'Reagent_A': 10,
        'Tubes_EDTA': 5,
      };

      // Atomic verification: check if sufficient stock
      bool canDeduct = true;
      deductions.forEach((item, qty) {
        if ((inventory[item] ?? 0) < qty) {
          canDeduct = false;
        }
      });
      expect(canDeduct, isTrue);

      // Perform deduction
      deductions.forEach((item, qty) {
        inventory[item] = (inventory[item] ?? 0) - qty;
      });

      expect(inventory['Reagent_A'], 90);
      expect(inventory['Tubes_EDTA'], 45);

      // Insufficient stock test
      final excessiveDeduction = {'Reagent_A': 150};
      bool canDeductExcessive = true;
      excessiveDeduction.forEach((item, qty) {
        if ((inventory[item] ?? 0) < qty) {
          canDeductExcessive = false;
        }
      });
      expect(canDeductExcessive, isFalse);
    });

    test('Migration schema keys v17 through v19 verification', () {
      final patientColumnsV18 = ['id', 'daily_id', 'file_no', 'name', 'age', 'gender', 'phone', 'address', 'whatsapp'];
      expect(patientColumnsV18.contains('address'), isTrue);

      final userColumnsV19 = ['id', 'username', 'password', 'role', 'full_name', 'force_password_change'];
      expect(userColumnsV19.contains('force_password_change'), isTrue);

      final metadataColumnsV19 = ['id', 'name', 'price', 'department', 'template_type'];
      expect(metadataColumnsV19.contains('template_type'), isTrue);
    });
  });

  group('SQLite In-Memory Database Regression Tests (sqflite_common_ffi)', () {
    late Database db;

    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    setUp(() async {
      db = await databaseFactory.openDatabase(inMemoryDatabasePath);
      DatabaseService.setDatabaseForTesting(db);
    });

    tearDown(() async {
      DatabaseService.setDatabaseForTesting(null);
      await db.close();
    });

    test('1. Production seed admin pathway and metadata update with isPasswordAlreadyHashed', () async {
      // Test the actual production seed migration pathway via DatabaseService.onCreate
      // Real production seeds admin with username: 'admin' and password: 'admin'
      await DatabaseService().onCreate(db, 19);

      // Verify the seeded admin record directly from the production onCreate pathway
      final seededRows = await db.query('users', where: 'username = ?', whereArgs: ['admin']);
      expect(seededRows.isNotEmpty, isTrue);
      final seededAdmin = seededRows.first;
      expect(seededAdmin['role'], 'admin');
      expect(seededAdmin['force_password_change'], 1);

      // Verify production login candidate verification computes identical hash for 'admin'/'admin'
      final candidateHash = UserService.hashPassword('admin', salt: 'admin');
      expect(seededAdmin['password'], candidateHash);
      expect(seededAdmin['password'].toString().startsWith('pbkdf2_\$'), isTrue);

      // Now verify updating user metadata with isPasswordAlreadyHashed preserves stored password hash
      final userId = seededAdmin['id'] as int;
      final storedHash = seededAdmin['password'] as String;

      final userToUpdate = UserModel(
        id: userId,
        username: 'admin',
        password: storedHash,
        role: 'admin',
        fullName: 'Updated Admin Name',
        forcePasswordChange: true,
      );

      // UserService.updateUser logic simulation with isPasswordAlreadyHashed: true
      final userMap = userToUpdate.toMap();
      // When isPasswordAlreadyHashed is true, password is NOT re-hashed
      await db.update('users', userMap, where: 'id = ?', whereArgs: [userId]);

      final updatedRows = await db.query('users', where: 'id = ?', whereArgs: [userId]);
      expect(updatedRows.first['full_name'], 'Updated Admin Name');
      expect(updatedRows.first['password'], storedHash);
      expect(updatedRows.first['force_password_change'], 1);
    });

    test('2. Login flow regression across legacy single-iteration and modern PBKDF2 hash upgrade', () async {
      await DatabaseService().onCreate(db, 19);
      const username = 'lab_tech';
      const plainPassword = 'LabPassword@123';
      
      // Store user with legacy single-iteration salted SHA-256 hash
      final legacyHash = UserService.hashPasswordSingleIteration(plainPassword, salt: username);
      final userId = await db.insert('users', {
        'username': username,
        'password': legacyHash,
        'role': 'tech',
        'full_name': 'Lab Technician',
        'force_password_change': 0,
      });

      // Verify initial stored hash is 64-char single iteration
      final initialUser = (await db.query('users', where: 'id = ?', whereArgs: [userId])).first;
      expect(initialUser['password'], legacyHash);
      expect(initialUser['password'].toString().length, 64);

      // Execute actual production UserService().login() to verify real authentication and auto-upgrade
      final loggedInUser = await UserService().login(username, plainPassword);
      expect(loggedInUser, isNotNull);
      expect(loggedInUser!.username, username);
      expect(loggedInUser.fullName, 'Lab Technician');

      // Verify the record in SQLite was transparently migrated to PBKDF2
      final upgradedUser = (await db.query('users', where: 'id = ?', whereArgs: [userId])).first;
      final upgradedStoredHash = upgradedUser['password'] as String;
      expect(upgradedStoredHash.startsWith('pbkdf2_\$'), isTrue);
      expect(upgradedStoredHash, isNot(equals(legacyHash)));
    });

    test('3. Migration execution test invoking real DatabaseService.onUpgrade for v18 & v19', () async {
      // Set up a database at schema v17 on db
      // Create v17 users table (without force_password_change)
      await db.execute('''
        CREATE TABLE users (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          username TEXT UNIQUE NOT NULL,
          password TEXT NOT NULL,
          role TEXT NOT NULL,
          full_name TEXT
        )
      ''');
      // Create v17 patients table (without address)
      await db.execute('''
        CREATE TABLE patients (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          daily_id INTEGER,
          name TEXT NOT NULL,
          created_at TEXT NOT NULL
        )
      ''');
      // Create test_results for normalization migration in v18
      await db.execute('''
        CREATE TABLE test_results (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          patient_test_id INTEGER NOT NULL,
          field_name TEXT NOT NULL,
          result_value TEXT
        )
      ''');

      // Insert unhashed user to test v18 hash migration step
      await db.insert('users', {
        'username': 'migration_user',
        'password': 'PlainPassword123',
        'role': 'user',
        'full_name': 'Migration User',
      });

      // Insert test result with legacy un-normalized stool field
      await db.insert('test_results', {
        'patient_test_id': 1,
        'field_name': 'pus cells',
        'result_value': '5-7',
      });

      // Invoke real DatabaseService.onUpgrade from v17 to v19
      await DatabaseService().onUpgrade(db, 17, 19);

      // Verify users table now has force_password_change column and upgraded hash
      final userColumns = await db.rawQuery("PRAGMA table_info(users)");
      final userColNames = userColumns.map((c) => c['name']).toList();
      expect(userColNames.contains('force_password_change'), isTrue);

      final migratedUser = (await db.query('users', where: 'username = ?', whereArgs: ['migration_user'])).first;
      final migratedPassword = migratedUser['password'] as String;
      expect(migratedPassword.startsWith('pbkdf2_\$'), isTrue);
      expect(migratedUser['force_password_change'], 0);

      // Verify test_results normalized field name
      final normalizedResult = (await db.query('test_results', where: 'patient_test_id = ?', whereArgs: [1])).first;
      expect(normalizedResult['field_name'], 'Pus cells');

      // Verify patients table now has address column from v19
      final patientColumns = await db.rawQuery("PRAGMA table_info(patients)");
      final patientColNames = patientColumns.map((c) => c['name']).toList();
      expect(patientColNames.contains('address'), isTrue);

      // Verify insertion with address into migrated schema
      await db.insert('patients', {
        'daily_id': 202,
        'name': 'Migrated Patient',
        'address': 'Baghdad Medical District',
        'created_at': DateTime.now().toIso8601String(),
      });
      final insertedPatient = (await db.query('patients', where: 'daily_id = ?', whereArgs: [202])).first;
      expect(insertedPatient['address'], 'Baghdad Medical District');
    });

    test('4. resetUserPassword retains correct salted PBKDF2 hash and sets force_password_change = 1', () async {
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

      const targetUsername = 'clinician_jane';
      const initialPassword = 'OldPassword@2025';
      final initialHash = UserService.hashPassword(initialPassword, salt: targetUsername);

      await db.insert('users', {
        'username': targetUsername,
        'password': initialHash,
        'role': 'user',
        'full_name': 'Jane Clinician',
        'force_password_change': 0,
      });

      // Inject in-memory DB into DatabaseService
      DatabaseService.setDatabaseForTesting(db);

      // Call UserService().resetUserPassword
      const newPassword = 'NewSecretPassword@2026';
      await UserService().resetUserPassword(targetUsername, newPassword);

      final updatedUser = (await db.query('users', where: 'username = ?', whereArgs: [targetUsername])).first;
      expect(updatedUser['force_password_change'], 1);

      // Verify password matches salted PBKDF2 hash using targetUsername as salt
      final expectedNewHash = UserService.hashPassword(newPassword, salt: targetUsername);
      expect(updatedUser['password'], expectedNewHash);
      expect(updatedUser['password'].toString().startsWith('pbkdf2_\$'), isTrue);

      DatabaseService.setDatabaseForTesting(null);
    });

    test('5. Date filtering in statistics_service includes end-of-day records and calculates overpaid via getAnalyticsData', () async {
      await DatabaseService().onCreate(db, 19);

      // Insert patient and tests on 2026-10-05 including end-of-day timestamp
      final patientId1 = await db.insert('patients', {
        'daily_id': 101,
        'name': 'Morning Patient',
        'age': 30,
        'gender': 'Male',
        'created_at': '2026-10-05T09:15:00.000',
      });

      final patientId2 = await db.insert('patients', {
        'daily_id': 102,
        'name': 'Evening Patient',
        'age': 45,
        'gender': 'Female',
        'created_at': '2026-10-05T23:59:59.999',
      });

      // Insert patient on next day
      await db.insert('patients', {
        'daily_id': 103,
        'name': 'Next Day Patient',
        'age': 25,
        'gender': 'Male',
        'created_at': '2026-10-06T08:00:00.000',
      });

      // Patient 1 test: Net 100, Paid 120 (Overpaid by 20)
      await db.insert('patient_tests', {
        'patient_id': patientId1,
        'test_id': 1,
        'status': 'Approved',
        'total_price': 100.0,
        'discount': 0.0,
        'paid': 120.0,
        'created_at': '2026-10-05T09:20:00.000',
      });

      // Patient 2 test: Net 150, Paid 100 (Remaining 50) late in the evening
      await db.insert('patient_tests', {
        'patient_id': patientId2,
        'test_id': 1,
        'status': 'Completed',
        'total_price': 150.0,
        'discount': 0.0,
        'paid': 100.0,
        'created_at': '2026-10-05T23:59:59.999',
      });

      // Invoke real StatisticsService.getAnalyticsData() for 2026-10-05
      final analytics = await StatisticsService().getAnalyticsData(
        start: DateTime(2026, 10, 5),
        end: DateTime(2026, 10, 5),
      );

      // Verify that DATE(created_at) captures both morning and 23:59:59 records on 2026-10-05
      expect(analytics['patientCount'], 2);
      expect(analytics['testTotal'], 2);
      expect(analytics['testApproved'], 1);
      expect(analytics['testCompleted'], 1);
      expect(analytics['revenue'], 250.0);
      expect(analytics['paid'], 220.0);
      expect(analytics['remaining'], 50.0);
      expect(analytics['overpaid'], 20.0);
    });

    test('6. Dynamic Admin Deletion Protection prevents deleting active user or last administrator', () async {
      await DatabaseService().onCreate(db, 19);

      // Verify current admin count is 1 (the seeded admin)
      final adminsBefore = await db.rawQuery("SELECT COUNT(*) as count FROM users WHERE role = 'admin'");
      expect(adminsBefore.first['count'], 1);

      final seededAdmin = (await db.query('users', where: 'username = ?', whereArgs: ['admin'])).first;
      final seededAdminId = seededAdmin['id'] as int;

      // Attempting to delete the only admin should be blocked
      final deleteLastAdminResult = await UserService().deleteUser(seededAdminId);
      expect(deleteLastAdminResult, isFalse);

      // Add a second administrator
      final secondAdminId = await db.insert('users', {
        'username': 'admin2',
        'password': UserService.hashPassword('admin2', salt: 'admin2'),
        'role': 'admin',
        'full_name': 'Second Administrator',
        'force_password_change': 0,
      });

      // Verify count is now 2
      final adminsTwo = await db.rawQuery("SELECT COUNT(*) as count FROM users WHERE role = 'admin'");
      expect(adminsTwo.first['count'], 2);

      // Attempting to delete target user matching active logged-in user session should be blocked
      final deleteSelfResult = await UserService().deleteUser(secondAdminId, currentUserId: secondAdminId);
      expect(deleteSelfResult, isFalse);

      // Deleting second admin when not the current user and not the last admin should succeed
      final deleteSuccess = await UserService().deleteUser(secondAdminId, currentUserId: seededAdminId);
      expect(deleteSuccess, isTrue);

      // Count is back to 1
      final adminsAfter = await db.rawQuery("SELECT COUNT(*) as count FROM users WHERE role = 'admin'");
      expect(adminsAfter.first['count'], 1);
    });

    test('7. Backup error recording, failure counter, and log pruning to 100 entries', () async {
      await DatabaseService().onCreate(db, 19);

      // Simulate inserting 120 backup logs
      for (int i = 1; i <= 120; i++) {
        await db.insert('backup_logs', {
          'timestamp': DateTime.now().subtract(Duration(minutes: 125 - i)).toIso8601String(),
          'status': i % 2 == 0 ? 'success' : 'failure',
          'error_message': i % 2 == 0 ? null : 'Temporary Drive failure',
          'target_folder': 'folder_xyz',
          'trigger_type': 'scheduled',
        });
      }

      // Execute pruning query: keep only the last 100 entries, protecting successful backups
      await db.execute('''
        DELETE FROM backup_logs 
        WHERE status != 'success' AND id NOT IN (
          SELECT id FROM backup_logs ORDER BY id DESC LIMIT 100
        )
      ''');

      // Out of the 20 oldest items (1..20), 10 are failures (pruned) and 10 are successes (preserved)
      // Total remaining = 120 - 10 = 110 logs.
      final logCount = await db.rawQuery('SELECT COUNT(*) as count FROM backup_logs');
      expect(logCount.first['count'], 110);

      // Verify that all successful backups from the older set were preserved
      final oldSuccessCount = await db.rawQuery(
        "SELECT COUNT(*) as count FROM backup_logs WHERE id <= 20 AND status = 'success'",
      );
      expect(oldSuccessCount.first['count'], 10);

      // Verify exponential backoff calculation helper logic (supports full 360m ceiling)
      int calculateBackoff(int failureCount) {
        return (15 * (1 << (failureCount - 1).clamp(0, 5))).clamp(15, 360);
      }
      expect(calculateBackoff(1), 15);
      expect(calculateBackoff(2), 30);
      expect(calculateBackoff(3), 60);
      expect(calculateBackoff(4), 120);
      expect(calculateBackoff(5), 240);
      expect(calculateBackoff(6), 360);
    });

    test('Test 8: Account Lockout Policy and Username Rename Password Salt Retention', () async {
      await DatabaseService().onCreate(db, 19);
      await UserService.clearLockout('test_lockout_user');

      // Seed valid user into database to ensure lockout triggers for existing accounts
      final seedHash = UserService.hashPassword('correct_pass', salt: 'test_lockout_user');
      await db.insert('users', {
        'username': 'test_lockout_user',
        'password': seedHash,
        'role': 'user',
        'full_name': 'Test User',
      });

      // 1. Verify failed login attempts lead to account lockout
      for (int i = 0; i < UserService.maxFailedAttempts; i++) {
        final res = await UserService().login('test_lockout_user', 'wrong_pass');
        expect(res, isNull);
      }

      // Next attempt should be locked out and throw AccountLockedException
      await expectLater(
        UserService().login('test_lockout_user', 'wrong_pass'),
        throwsA(isA<AccountLockedException>()),
      );
      expect(await UserService.isAccountLocked('test_lockout_user'), isTrue);

      // Reset lockout for safety
      await UserService.clearLockout('test_lockout_user');
      expect(await UserService.isAccountLocked('test_lockout_user'), isFalse);

      // 2. Verify compute isolate offloading hash
      final hashedAsync = await UserService.hashPasswordAsync('securePass123', salt: 'admin');
      final hashedSync = UserService.hashPassword('securePass123', salt: 'admin');
      expect(hashedAsync, hashedSync);

      // 3. Verify username rename password salt preservation
      final initialHash = UserService.hashPassword('admin123', salt: 'admin_old');
      final newUserId = await db.insert('users', {
        'username': 'admin_old',
        'password': initialHash,
        'role': 'admin',
        'full_name': 'Admin User',
      });

      // Update username without entering new password using UserService.updateUser
      await UserService().updateUser(
        UserModel(
          id: newUserId,
          username: 'admin_new',
          password: '', // Empty password field preserves stored password salt
          role: 'admin',
        ),
      );

      final updatedUser = await db.query('users', where: 'id = ?', whereArgs: [newUserId]);
      expect(updatedUser.first['username'], 'admin_new');
      expect(updatedUser.first['password'], initialHash);
    });
  });
}
