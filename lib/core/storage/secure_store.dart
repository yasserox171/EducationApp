import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../data/models/user.dart';

/// تخزين آمن للجلسة (JWT + بيانات المستخدم) عبر Keychain/Keystore.
class SecureStore {
  SecureStore([FlutterSecureStorage? storage])
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock,
              ),
            );

  final FlutterSecureStorage _storage;

  static const String _sessionKey = 'auth_session';

  Future<AuthSession?> readSession() async {
    final raw = await _storage.read(key: _sessionKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final session =
          AuthSession.fromJson(Map<String, dynamic>.from(decoded));
      return session.token.isEmpty ? null : session;
    } catch (_) {
      // بيانات تالفة — نتعامل معها كأن لا جلسة.
      await clearSession();
      return null;
    }
  }

  Future<void> writeSession(AuthSession session) =>
      _storage.write(key: _sessionKey, value: jsonEncode(session.toJson()));

  Future<void> clearSession() => _storage.delete(key: _sessionKey);
}
