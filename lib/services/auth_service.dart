import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  static const _keyUsername = 'auth_username';
  static const _keyPasswordHash = 'auth_password_hash';

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  /// Inicializa el usuario por defecto si no existe ninguno registrado.
  Future<void> initDefaultUser() async {
    final existing = await _storage.read(key: _keyUsername);
    if (existing == null || existing.isEmpty) {
      await registerUser('admin', 'password123');
    }
  }

  /// Registra un nuevo usuario con contraseña hasheada.
  Future<bool> registerUser(String username, String password) async {
    try {
      final hash = _hashPassword(password);
      await _storage.write(key: _keyUsername, value: username);
      await _storage.write(key: _keyPasswordHash, value: hash);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Valida las credenciales contra el almacenamiento seguro.
  Future<bool> validateCredentials(String username, String password) async {
    final storedUser = await _storage.read(key: _keyUsername);
    final storedHash = await _storage.read(key: _keyPasswordHash);

    if (storedUser == null || storedHash == null) return false;

    final inputHash = _hashPassword(password);
    return storedUser == username && storedHash == inputHash;
  }

  /// Cierra la sesión eliminando las credenciales.
  Future<void> logout() async {
    await _storage.delete(key: _keyUsername);
    await _storage.delete(key: _keyPasswordHash);
  }

  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
}
