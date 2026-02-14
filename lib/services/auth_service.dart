import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import 'encryption_service.dart';

/// Firestore-based authentication service with persistent session.
///
/// Session is stored in SharedPreferences so the user stays logged in
/// after app restart / hot-reload / device reboot.
class AuthService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _random = Random.secure();

  static const _keyUid = 'vizo_session_uid';
  static const _keyPhone = 'vizo_session_phone';

  // ─── Session ───────────────────────────────────────

  String? _sessionUid;
  String? _sessionPhone;

  String get effectiveUid => _sessionUid ?? '';
  String get uid => effectiveUid;
  String get phoneNumber => _sessionPhone ?? '';
  bool get isSignedIn => _sessionUid != null && _sessionUid!.isNotEmpty;

  Stream<dynamic> get authStateChanges => const Stream.empty();

  /// Try to restore session from SharedPreferences.
  /// Returns `true` if a valid session was found.
  Future<bool> tryRestoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUid = prefs.getString(_keyUid);
    final savedPhone = prefs.getString(_keyPhone);
    if (savedUid != null && savedUid.isNotEmpty) {
      // Verify user still exists in Firestore
      final doc = await _firestore.collection('users').doc(savedUid).get();
      if (doc.exists) {
        _sessionUid = savedUid;
        _sessionPhone = savedPhone ?? '';
        // Mark online
        try {
          await _firestore.collection('users').doc(savedUid).update({
            'isOnline': true,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } catch (_) {}
        return true;
      } else {
        await prefs.remove(_keyUid);
        await prefs.remove(_keyPhone);
      }
    }
    return false;
  }

  Future<void> _saveSession() async {
    final prefs = await SharedPreferences.getInstance();
    if (_sessionUid != null) {
      await prefs.setString(_keyUid, _sessionUid!);
      await prefs.setString(_keyPhone, _sessionPhone ?? '');
    }
  }

  Future<void> _clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyUid);
    await prefs.remove(_keyPhone);
  }

  // ─── Send OTP ──────────────────────────────────────

  Future<void> sendOtp({
    required String phoneNumber,
    required void Function(String verificationId) onCodeSent,
    required void Function(String error) onError,
    int? resendToken,
  }) async {
    try {
      final phone = phoneNumber.trim();
      if (phone.length < 8) {
        onError('Неверный номер телефона');
        return;
      }

      final code = (100000 + _random.nextInt(900000)).toString();
      final docId = _sanitizePhone(phone);

      await _firestore.collection('otp_codes').doc(docId).set({
        'phone': phone,
        'code': code,
        'createdAt': FieldValue.serverTimestamp(),
        'verified': false,
      });

      onCodeSent(phone);
    } catch (e) {
      onError('Ошибка: $e');
    }
  }

  Future<String?> getTestCode(String phoneNumber) async {
    try {
      final docId = _sanitizePhone(phoneNumber.trim());
      final doc = await _firestore.collection('otp_codes').doc(docId).get();
      if (!doc.exists) return null;
      final data = doc.data()!;
      if (data['verified'] == true) return null;
      return data['code'] as String?;
    } catch (_) {
      return null;
    }
  }

  // ─── Verify OTP ────────────────────────────────────

  Future<UserModel?> verifyOtp({
    required String verificationId,
    required String smsCode,
  }) async {
    final phone = verificationId.trim();
    final docId = _sanitizePhone(phone);

    final doc = await _firestore.collection('otp_codes').doc(docId).get();
    if (!doc.exists) {
      throw Exception('Код не найден. Запросите новый.');
    }

    final data = doc.data()!;
    final storedCode = data['code'] as String? ?? '';

    if (storedCode != smsCode.trim()) {
      throw Exception('Неверный код');
    }

    await _firestore.collection('otp_codes').doc(docId).update({
      'verified': true,
    });

    final uid = docId;
    final user = await _ensureUserDoc(uid: uid, phoneNumber: phone);

    _sessionUid = uid;
    _sessionPhone = phone;
    await _saveSession();

    return user;
  }

  // ─── User Doc ──────────────────────────────────────

  Future<UserModel> _ensureUserDoc({
    required String uid,
    required String phoneNumber,
  }) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (doc.exists) {
      await _firestore.collection('users').doc(uid).update({
        'isOnline': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return UserModel.fromFirestore(doc);
    } else {
      final encryptionKey = EncryptionService.generateKey();
      final newUser = UserModel(
        uid: uid,
        phoneNumber: phoneNumber,
        encryptionKey: encryptionKey,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isOnline: true,
      );
      await _firestore.collection('users').doc(uid).set(newUser.toFirestore());
      return newUser;
    }
  }

  /// Check if user profile is complete (has displayName).
  Future<bool> isProfileComplete() async {
    if (effectiveUid.isEmpty) return false;
    final doc = await _firestore.collection('users').doc(effectiveUid).get();
    if (!doc.exists) return false;
    final name = doc.data()?['displayName'] as String? ?? '';
    return name.trim().isNotEmpty;
  }

  Future<UserModel?> getCurrentUserModel() async {
    final id = effectiveUid;
    if (id.isEmpty) return null;
    final doc = await _firestore.collection('users').doc(id).get();
    if (!doc.exists) return null;
    return UserModel.fromFirestore(doc);
  }

  // ─── Sign Out ──────────────────────────────────────

  Future<void> signOut() async {
    if (_sessionUid != null) {
      try {
        await _firestore.collection('users').doc(_sessionUid!).update({
          'isOnline': false,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } catch (_) {}
    }
    _sessionUid = null;
    _sessionPhone = null;
    await _clearSession();
  }

  // ─── Helpers ───────────────────────────────────────

  String _sanitizePhone(String phone) {
    return phone.replaceAll(RegExp(r'[^0-9+]'), '').replaceAll('+', 'p');
  }
}
