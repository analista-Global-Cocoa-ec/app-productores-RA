import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/usuario.dart';

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  static const _keyUsers = 'auth_users';
  static const _keyLegacyUsername = 'auth_username';
  static const _keyLegacyPasswordHash = 'auth_password_hash';

  static const String defaultAdminUsername = 'admin';
  static const String defaultAdminPassword = 'password123';
  static const String defaultTecnicoUsername = 'tecnico';
  static const String defaultTecnicoPassword = 'tecnico123';

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  Usuario? _usuarioActual;

  /// Usuario autenticado actualmente, o `null` si no hay sesión.
  Usuario? get usuarioActual => _usuarioActual;

  /// Permite a las pantallas habilitar acciones exclusivas del Administrador.
  bool get esAdministrador =>
      _usuarioActual?.perfil == PerfilUsuario.administrador;

  bool get esTecnico => _usuarioActual?.perfil == PerfilUsuario.tecnico;

  /// Crea los dos usuarios por defecto si aún no existen.
  ///
  /// Si la app venía de la versión de un solo usuario, migra esas credenciales
  /// al perfil Administrador para no perder la contraseña existente.
  Future<void> initDefaultUsers() async {
    try {
      final usuarios = await _leerUsuarios();

      if (usuarios.isEmpty) {
        final legacyUsername = await _storage.read(key: _keyLegacyUsername);
        final legacyHash = await _storage.read(key: _keyLegacyPasswordHash);
        if (legacyUsername != null &&
            legacyUsername.isNotEmpty &&
            legacyHash != null &&
            legacyHash.isNotEmpty) {
          usuarios.add(
            _UsuarioCredencial(
              username: legacyUsername,
              passwordHash: legacyHash,
              perfil: PerfilUsuario.administrador,
            ),
          );
        }
      }

      var cambios = false;
      cambios =
          _asegurarUsuario(
            usuarios,
            username: defaultAdminUsername,
            password: defaultAdminPassword,
            perfil: PerfilUsuario.administrador,
          ) ||
          cambios;
      cambios =
          _asegurarUsuario(
            usuarios,
            username: defaultTecnicoUsername,
            password: defaultTecnicoPassword,
            perfil: PerfilUsuario.tecnico,
          ) ||
          cambios;

      if (cambios) {
        await _guardarUsuarios(usuarios);
      }

      // Las claves antiguas ya no se usan; se eliminan tras la migración.
      await _storage.delete(key: _keyLegacyUsername);
      await _storage.delete(key: _keyLegacyPasswordHash);
    } catch (error) {
      debugPrint('No se pudieron inicializar los usuarios: $error');
    }
  }

  /// Valida las credenciales y, si son correctas, inicia la sesión.
  Future<Usuario?> autenticar(String username, String password) async {
    var usuarios = await _leerUsuarios();

    // Salvaguarda por si la app se actualizó sin reiniciar main().
    if (usuarios.isEmpty) {
      await initDefaultUsers();
      usuarios = await _leerUsuarios();
    }

    final hash = _hashPassword(password);
    final usuarioNormalizado = username.trim();

    for (final credencial in usuarios) {
      if (credencial.username == usuarioNormalizado &&
          credencial.passwordHash == hash) {
        _usuarioActual = Usuario(
          username: credencial.username,
          perfil: credencial.perfil,
        );
        return _usuarioActual;
      }
    }

    return null;
  }

  Future<bool> validateCredentials(String username, String password) async {
    return await autenticar(username, password) != null;
  }

  /// Cierra la sesión actual sin eliminar los usuarios registrados.
  Future<void> logout() async {
    _usuarioActual = null;
  }

  Future<bool> registrarUsuario({
    required String username,
    required String password,
    required PerfilUsuario perfil,
  }) async {
    try {
      final nombre = username.trim();
      if (nombre.isEmpty || password.isEmpty) return false;

      final usuarios = await _leerUsuarios();
      if (usuarios.any((usuario) => usuario.username == nombre)) {
        return false;
      }

      usuarios.add(
        _UsuarioCredencial(
          username: nombre,
          passwordHash: _hashPassword(password),
          perfil: perfil,
        ),
      );
      await _guardarUsuarios(usuarios);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Garantiza que exista [username] con el perfil indicado. No cambia la
  /// contraseña si el usuario ya existía.
  bool _asegurarUsuario(
    List<_UsuarioCredencial> usuarios, {
    required String username,
    required String password,
    required PerfilUsuario perfil,
  }) {
    for (var i = 0; i < usuarios.length; i++) {
      final usuario = usuarios[i];
      if (usuario.username != username) continue;

      if (usuario.perfil == perfil) return false;

      usuarios[i] = _UsuarioCredencial(
        username: usuario.username,
        passwordHash: usuario.passwordHash,
        perfil: perfil,
      );
      return true;
    }

    usuarios.add(
      _UsuarioCredencial(
        username: username,
        passwordHash: _hashPassword(password),
        perfil: perfil,
      ),
    );
    return true;
  }

  Future<List<_UsuarioCredencial>> _leerUsuarios() async {
    final raw = await _storage.read(key: _keyUsers);
    if (raw == null || raw.isEmpty) return [];

    try {
      final data = jsonDecode(raw);
      if (data is! List) return [];

      return data
          .whereType<Map>()
          .map(
            (item) =>
                _UsuarioCredencial.fromJson(Map<String, dynamic>.from(item)),
          )
          .where(
            (usuario) =>
                usuario.username.isNotEmpty && usuario.passwordHash.isNotEmpty,
          )
          .toList();
    } catch (error) {
      debugPrint('No se pudieron leer los usuarios almacenados: $error');
      return [];
    }
  }

  Future<void> _guardarUsuarios(List<_UsuarioCredencial> usuarios) async {
    final data = jsonEncode(
      usuarios.map((usuario) => usuario.toJson()).toList(),
    );
    await _storage.write(key: _keyUsers, value: data);
  }

  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
}

/// Credenciales persistidas en almacenamiento seguro.
class _UsuarioCredencial {
  final String username;
  final String passwordHash;
  final PerfilUsuario perfil;

  const _UsuarioCredencial({
    required this.username,
    required this.passwordHash,
    required this.perfil,
  });

  factory _UsuarioCredencial.fromJson(Map<String, dynamic> json) {
    return _UsuarioCredencial(
      username: json['username'] as String? ?? '',
      passwordHash: json['passwordHash'] as String? ?? '',
      perfil: PerfilUsuario.desdeJson(json['perfil']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'passwordHash': passwordHash,
      'perfil': perfil.name,
    };
  }
}
