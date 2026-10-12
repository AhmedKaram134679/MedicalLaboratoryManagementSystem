import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../models/user_model.dart';
import 'database_service.dart';
import 'audit_service.dart';

/// Top-level parameter container for PBKDF2 compute isolate offloading
class _Pbkdf2HashParams {
  final String password;
  final String? salt;
  final int iterations;

  const _Pbkdf2HashParams({
    required this.password,
    this.salt,
    required this.iterations,
  });
}

/// Pure top-level worker for compute() isolate execution
String _executePbkdf2Hash(_Pbkdf2HashParams params) {
  return UserService.hashPassword(
    params.password,
    salt: params.salt,
    iterations: params.iterations,
  );
}

class UserService {
  final DatabaseService _dbService = DatabaseService();

  static const int _hashIterations = 10000;
  static const int _derivedKeyBytes = 32;

  // Account Lockout Policy
  static const int maxFailedAttempts = 5;
  static const int initialLockoutMinutes = 15;
  // In-memory lockout and failure attempt registry: username -> _LockoutRecord
  static final Map<String, _LockoutRecord> _lockoutRegistry = {};

  /// Standard PBKDF2-HMAC-SHA256 key derivation with per-user salt token
  static String hashPassword(String password, {String? salt, int iterations = _hashIterations}) {
    final effectiveSalt = (salt != null && salt.isNotEmpty)
        ? salt.toLowerCase().trim()
        : 'mlms_secure_salt_2026';

    final saltBytes = utf8.encode(effectiveSalt);
    final passwordBytes = utf8.encode(password);

    // Standard PBKDF2-HMAC-SHA256 derivation:
    // U_1 = PRF(Password, Salt || INT_32_BE(1))
    // U_k = PRF(Password, U_{k-1})
    // F = U_1 ^ U_2 ^ ... ^ U_c
    final hmac = Hmac(sha256, passwordBytes);
    final initialBlock = <int>[...saltBytes, 0, 0, 0, 1];
    var u = hmac.convert(initialBlock).bytes;
    final f = List<int>.from(u);

    for (int i = 1; i < iterations; i++) {
      u = hmac.convert(u).bytes;
      for (int k = 0; k < f.length; k++) {
        f[k] ^= u[k];
      }
    }

    final derivedBytes = f.sublist(0, _derivedKeyBytes);
    final hexDigest = derivedBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return 'pbkdf2_\$i$iterations\$$hexDigest';
  }

  /// Offload PBKDF2 cryptographic derivations via compute() to prevent UI thread freezing
  static Future<String> hashPasswordAsync(String password, {String? salt, int iterations = _hashIterations}) async {
    return await compute(
      _executePbkdf2Hash,
      _Pbkdf2HashParams(password: password, salt: salt, iterations: iterations),
    );
  }

  /// Check whether an account is currently locked out (checks in-memory registry and persistent storage)
  static Future<bool> isAccountLocked(String username) async {
    final key = username.toLowerCase().trim();
    final record = _lockoutRegistry[key];
    if (record?.lockoutUntil != null) {
      if (DateTime.now().isBefore(record!.lockoutUntil!)) {
        return true;
      } else {
        // Cooldown expired: reset lockout status but keep record clean
        _lockoutRegistry.remove(key);
        try {
          final db = await DatabaseService().database;
          await db.delete('app_settings', where: 'key = ?', whereArgs: ['lockout_$key']);
        } catch (_) {}
        return false;
      }
    }

    // Check persistent storage in app_settings
    try {
      final db = await DatabaseService().database;
      final rows = await db.query('app_settings', where: 'key = ?', whereArgs: ['lockout_$key']);
      if (rows.isNotEmpty) {
        final lockUntilStr = rows.first['value'] as String?;
        if (lockUntilStr != null) {
          final lockUntil = DateTime.tryParse(lockUntilStr);
          if (lockUntil != null && DateTime.now().isBefore(lockUntil)) {
            // Restore to memory cache along with persisted multiplier
            final multRows = await db.query('app_settings', where: 'key = ?', whereArgs: ['lockout_mult_$key']);
            int mult = 1;
            if (multRows.isNotEmpty) {
              mult = int.tryParse(multRows.first['value'] as String? ?? '1') ?? 1;
            }
            final restored = _LockoutRecord();
            restored.failedAttempts = maxFailedAttempts;
            restored.lockoutMultiplier = mult;
            restored.lockoutUntil = lockUntil;
            _lockoutRegistry[key] = restored;
            return true;
          } else {
            await db.delete('app_settings', where: 'key IN (?, ?)', whereArgs: ['lockout_$key', 'lockout_mult_$key']);
          }
        }
      }
    } catch (_) {}

    return false;
  }

  /// Gets remaining lockout duration for a locked account in minutes
  static Future<int> getRemainingLockoutMinutes(String username) async {
    final key = username.toLowerCase().trim();
    final record = _lockoutRegistry[key];
    if (record?.lockoutUntil != null) {
      final diff = record!.lockoutUntil!.difference(DateTime.now()).inMinutes;
      return diff > 0 ? diff + 1 : 1;
    }

    // Fallback to checking persisted record
    try {
      final db = await DatabaseService().database;
      final rows = await db.query('app_settings', where: 'key = ?', whereArgs: ['lockout_$key']);
      if (rows.isNotEmpty) {
        final lockUntilStr = rows.first['value'] as String?;
        if (lockUntilStr != null) {
          final lockUntil = DateTime.tryParse(lockUntilStr);
          if (lockUntil != null) {
            final diff = lockUntil.difference(DateTime.now()).inMinutes;
            return diff > 0 ? diff + 1 : 1;
          }
        }
      }
    } catch (_) {}

    return 0;
  }

  /// Constant-time digest comparison to prevent timing attacks
  static bool verifyHash(String calculated, String stored) {
    if (calculated.length != stored.length) return false;
    int diff = 0;
    for (int i = 0; i < calculated.length; i++) {
      diff |= calculated.codeUnitAt(i) ^ stored.codeUnitAt(i);
    }
    return diff == 0;
  }

  /// Single iteration SHA-256 with delimiter (used in previous format)
  static String hashPasswordSingleIteration(String password, {String? salt}) {
    final effectiveSalt = (salt != null && salt.isNotEmpty)
        ? salt.toLowerCase().trim()
        : 'mlms_secure_salt_2026';
    final bytes = utf8.encode('$password::$effectiveSalt');
    return sha256.convert(bytes).toString();
  }

  /// Legacy pseudo-PBKDF2 format (sha256 initial + HMAC stretch with salt as key)
  static String hashPasswordPseudoPbkdf2(String password, {String? salt, int iterations = _hashIterations}) {
    final effectiveSalt = (salt != null && salt.isNotEmpty)
        ? salt.toLowerCase().trim()
        : 'mlms_secure_salt_2026';
    
    var currentBytes = utf8.encode('$password::$effectiveSalt');
    var digest = sha256.convert(currentBytes);

    final hmacKey = utf8.encode(effectiveSalt);
    final hmac = Hmac(sha256, hmacKey);
    for (int i = 1; i < iterations; i++) {
      digest = hmac.convert(digest.bytes);
    }

    return 'pbkdf2_\$i$iterations\$${digest.toString()}';
  }

  /// Legacy static salt hashing used in previous builds
  static String hashPasswordLegacy(String password) {
    final bytes = utf8.encode('$password::mlms_salt_${password.length}_dynamic');
    return sha256.convert(bytes).toString();
  }

  /// Old fallback static salt
  static String hashPasswordOldStatic(String password) {
    final bytes = utf8.encode('$password::mlms_secure_salt_2026');
    return sha256.convert(bytes).toString();
  }

  /// Legacy formula without delimiter: sha256(password + salt)
  static String hashPasswordLegacyNoDelimiter(String password, {String? salt}) {
    final effectiveSalt = (salt != null && salt.isNotEmpty)
        ? salt.toLowerCase().trim()
        : 'mlms_secure_salt_2026';
    final bytes = utf8.encode('$password$effectiveSalt');
    return sha256.convert(bytes).toString();
  }

  Future<void> clearForcePasswordChange(int userId) async {
    final db = await _dbService.database;
    await db.update(
      'users',
      {'force_password_change': 0},
      where: 'id = ?',
      whereArgs: [userId],
    );
  }

  Future<List<UserModel>> getAllUsers() async {
    final db = await _dbService.database;
    final List<Map<String, dynamic>> maps = await db.query('users');
    return List.generate(maps.length, (i) => UserModel.fromMap(maps[i]));
  }

  Future<int> addUser(UserModel user) async {
    final db = await _dbService.database;
    final userMap = user.toMap();
    userMap['password'] = hashPassword(user.password, salt: user.username);
    return await db.insert('users', userMap);
  }

  Future<void> updateUser(UserModel user, {bool isPasswordAlreadyHashed = false}) async {
    final db = await _dbService.database;
    final userMap = user.toMap();

    // Fix Username Renaming Bug:
    // If username is renamed and password was kept unchanged (isPasswordAlreadyHashed == true or user.password is empty),
    // the previous password hash was keyed to the old username as salt!
    // We check the existing username from DB and ensure the salt remains valid.
    final existingUserList = await db.query('users', where: 'id = ?', whereArgs: [user.id]);
    if (existingUserList.isNotEmpty) {
      final existingUser = existingUserList.first;
      final existingUsername = (existingUser['username'] as String?) ?? '';
      final existingStoredHash = (existingUser['password'] as String?) ?? '';

      if (user.password.isNotEmpty) {
        if (!isPasswordAlreadyHashed) {
          // New plaintext password provided: hash with the new username
          userMap['password'] = hashPassword(user.password, salt: user.username);
        } else {
          // Password was unchanged (already hashed). If username changed, preserve the existing valid hash
          userMap['password'] = existingStoredHash;
        }
      } else {
        // Password field was omitted: preserve existing hash
        userMap['password'] = existingStoredHash;
      }

      // If username changed, log audit trail
      if (existingUsername.isNotEmpty && existingUsername != user.username) {
        await AuditService().logAction(
          action: 'تعديل اسم المستخدم من "$existingUsername" إلى "${user.username}"',
          dataType: 'Users',
          userName: 'System',
        );
      }
    } else {
      if (user.password.isNotEmpty && !isPasswordAlreadyHashed) {
        userMap['password'] = hashPassword(user.password, salt: user.username);
      }
    }

    await db.update(
      'users',
      userMap,
      where: 'id = ?',
      whereArgs: [user.id],
    );
  }

  /// Deletes a user dynamically preventing self-deletion or deletion of the last admin
  Future<bool> deleteUser(int id, {int? currentUserId}) async {
    final db = await _dbService.database;

    // 1. Prevent self-deletion
    if (currentUserId != null && id == currentUserId) {
      return false;
    }

    // 2. Prevent deleting the last remaining active Administrator
    final targetUser = await db.query('users', where: 'id = ?', whereArgs: [id]);
    if (targetUser.isEmpty) return false;

    final targetRole = targetUser.first['role'] as String?;
    if (targetRole == 'admin') {
      final adminCountResult = await db.rawQuery(
        "SELECT COUNT(*) as count FROM users WHERE role = 'admin'",
      );
      final adminCount = (adminCountResult.first['count'] as int?) ?? 0;
      if (adminCount <= 1) {
        return false; // Cannot delete the only remaining administrator
      }
    }

    final deletedRows = await db.delete('users', where: 'id = ?', whereArgs: [id]);
    return deletedRows > 0;
  }

  Future<bool> isAdmin(int userId) async {
    final db = await _dbService.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'users',
      columns: ['role'],
      where: 'id = ?',
      whereArgs: [userId],
    );
    if (maps.isEmpty) return false;
    return maps.first['role'] == 'admin';
  }

  Future<UserModel?> login(String username, String password) async {
    final cleanUsername = username.trim();
    final lowerUsername = cleanUsername.toLowerCase();

    // 1. Check account lockout state (persisted in DB/memory)
    if (await isAccountLocked(cleanUsername)) {
      final remainingMins = await getRemainingLockoutMinutes(cleanUsername);
      await AuditService().logAction(
        action: 'محاولة تسجيل دخول مرفوضة لحساب مقفل مؤقتاً: "$cleanUsername" (متبقي $remainingMins دقيقة)',
        dataType: 'Authentication',
        userName: cleanUsername,
      );
      throw AccountLockedException(
        'تم قفل هذا الحساب مؤقتاً بسبب تكرار محاولات الدخول الخاطئة. يرجى الانتظار $remainingMins دقيقة قبل المحاولة مجدداً.',
        remainingMinutes: remainingMins,
      );
    }

    final db = await _dbService.database;
    final List<Map<String, dynamic>> users = await db.query(
      'users',
      where: 'LOWER(username) = ?',
      whereArgs: [lowerUsername],
    );

    // If username doesn't exist, do NOT lock out existing user accounts.
    if (users.isEmpty) {
      return null;
    }

    final userRow = users.first;
    final String storedHash = (userRow['password'] as String?) ?? '';

    // Fast-path: Calculate standard PBKDF2-HMAC-SHA256 candidate offloaded to compute() isolate
    final candidatePbkdf2 = await hashPasswordAsync(password, salt: cleanUsername);
    bool isMatch = false;
    bool needsUpgrade = false;

    if (verifyHash(candidatePbkdf2, storedHash)) {
      isMatch = true;
    } else {
      // Lazy-evaluation: check pseudo-PBKDF2 and other legacy formats
      // Note: pseudo-PBKDF2 produces hashes that also start with 'pbkdf2_$i10000$',
      // so we must check it even if storedHash starts with 'pbkdf2_$i10000$'.
      final candidatePseudoPbkdf2 = hashPasswordPseudoPbkdf2(password, salt: cleanUsername);
      if (verifyHash(candidatePseudoPbkdf2, storedHash)) {
        isMatch = true;
        needsUpgrade = true;
      } else if (!storedHash.startsWith('pbkdf2_\$i10000\$')) {
        final candidateSingleIteration = hashPasswordSingleIteration(password, salt: cleanUsername);
        final candidateLegacyNoDelimiter = hashPasswordLegacyNoDelimiter(password, salt: cleanUsername);
        final candidateLegacy = hashPasswordLegacy(password);
        final candidateOldStatic = hashPasswordOldStatic(password);
        final candidateOldStaticNoDelim = hashPasswordLegacyNoDelimiter(password);

        if (verifyHash(candidateSingleIteration, storedHash) ||
            verifyHash(candidateLegacyNoDelimiter, storedHash) ||
            verifyHash(candidateLegacy, storedHash) ||
            verifyHash(candidateOldStatic, storedHash) ||
            verifyHash(candidateOldStaticNoDelim, storedHash)) {
          isMatch = true;
          needsUpgrade = true;
        }
      }
    }

    if (!isMatch) {
      await _recordFailedLoginAttempt(cleanUsername);
      return null;
    }

    // Login successful: reset lockout failed attempt counter
    await clearLockout(lowerUsername);

    final updatedRow = Map<String, dynamic>.from(userRow);
    if (needsUpgrade) {
      // Re-hash and transparently upgrade database record to standard PBKDF2 format
      final newHash = await hashPasswordAsync(password, salt: cleanUsername);
      await db.update(
        'users',
        {'password': newHash},
        where: 'id = ?',
        whereArgs: [userRow['id']],
      );
      updatedRow['password'] = newHash;
    }

    return UserModel.fromMap(updatedRow);
  }

  /// Records a failed login attempt, triggers lockout policy after 5 failures with exponential cooldown
  static Future<void> _recordFailedLoginAttempt(String username) async {
    final key = username.toLowerCase().trim();
    // Ensure existing persisted multiplier is considered if memory record was empty
    if (!_lockoutRegistry.containsKey(key)) {
      await isAccountLocked(key);
    }
    final record = _lockoutRegistry[key] ?? _LockoutRecord();
    record.failedAttempts += 1;
    record.lastFailureTime = DateTime.now();

    if (record.failedAttempts >= maxFailedAttempts) {
      record.lockoutMultiplier = (record.lockoutMultiplier <= 0) ? 1 : record.lockoutMultiplier * 2;
      final lockoutDuration = Duration(minutes: initialLockoutMinutes * record.lockoutMultiplier);
      record.lockoutUntil = DateTime.now().add(lockoutDuration);

      await AuditService().logAction(
        action: 'قفل أمني للحساب "$username" بعد ${record.failedAttempts} محاولات دخول فاشلة متتالية لمدة ${lockoutDuration.inMinutes} دقيقة',
        dataType: 'SecurityAudit',
        userName: username,
      );

      // Persist lockout timestamp and multiplier into app_settings to survive restarts
      try {
        final db = await DatabaseService().database;
        await db.insert('app_settings', {
          'key': 'lockout_$key',
          'value': record.lockoutUntil!.toIso8601String(),
        }, conflictAlgorithm: ConflictAlgorithm.replace);
        await db.insert('app_settings', {
          'key': 'lockout_mult_$key',
          'value': record.lockoutMultiplier.toString(),
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      } catch (e) {
        debugPrint('Lockout persistence error: $e');
      }
    } else {
      await AuditService().logAction(
        action: 'فشل محاولة تسجيل دخول للحساب "$username" (المحاولة ${record.failedAttempts} من $maxFailedAttempts)',
        dataType: 'SecurityAudit',
        userName: username,
      );
    }

    _lockoutRegistry[key] = record;
  }

  /// Reset lockout state for administrative overrides or testing
  static Future<void> clearLockout(String username) async {
    final key = username.toLowerCase().trim();
    _lockoutRegistry.remove(key);
    try {
      final db = await DatabaseService().database;
      await db.delete('app_settings', where: 'key IN (?, ?)', whereArgs: ['lockout_$key', 'lockout_mult_$key']);
    } catch (_) {}
  }

  Future<bool> createPasswordRecoveryRequest(String username) async {
    final db = await _dbService.database;
    final cleanUsername = username.trim();
    final userCheck = await db.query(
      'users',
      where: 'LOWER(username) = ?',
      whereArgs: [cleanUsername.toLowerCase()],
    );
    if (userCheck.isEmpty) {
      return false; // User not found
    }
    await db.insert('admin_requests', {
      'username': userCheck.first['username'] ?? cleanUsername,
      'request_type': 'Password Recovery',
      'created_at': DateTime.now().toIso8601String(),
      'status': 'Pending',
    });
    return true;
  }

  Future<void> createUnapproveRequest(String username, int patientTestId, String testName) async {
    final db = await _dbService.database;
    await db.insert('admin_requests', {
      'username': username,
      'request_type': 'Unapprove Test',
      'details': 'patient_test_id:$patientTestId - test:$testName',
      'created_at': DateTime.now().toIso8601String(),
      'status': 'Pending',
    });
  }

  Future<List<Map<String, dynamic>>> getPendingRequests() async {
    final db = await _dbService.database;
    return await db.query(
      'admin_requests',
      where: 'status = ?',
      whereArgs: ['Pending'],
      orderBy: 'created_at DESC',
    );
  }

  Future<void> updateRequestStatus(int requestId, String status) async {
    final db = await _dbService.database;
    await db.update(
      'admin_requests',
      {'status': status},
      where: 'id = ?',
      whereArgs: [requestId],
    );
  }

  Future<void> resetUserPassword(String username, String newPassword) async {
    final db = await _dbService.database;
    final hashed = hashPassword(newPassword, salt: username);
    await db.update(
      'users',
      {
        'password': hashed,
        'force_password_change': 1,
      },
      where: 'username = ?',
      whereArgs: [username],
    );
  }
}

/// Internal helper class tracking login attempts and lockout timestamps
class _LockoutRecord {
  int failedAttempts = 0;
  int lockoutMultiplier = 0;
  DateTime? lastFailureTime;
  DateTime? lockoutUntil;
}

/// Thrown when an account is temporarily locked due to excessive failed attempts
class AccountLockedException implements Exception {
  final String message;
  final int remainingMinutes;

  AccountLockedException(this.message, {required this.remainingMinutes});

  @override
  String toString() => message;
}
