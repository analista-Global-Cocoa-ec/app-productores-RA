/// Perfiles disponibles en la aplicación.
///
/// Por ahora ambos perfiles tienen acceso a las mismas pantallas y a la misma
/// colección de Firestore. El perfil se guarda en la sesión para poder
/// restringir acciones del Administrador en el futuro.
enum PerfilUsuario {
  administrador('Administrador'),
  tecnico('Tecnico');

  const PerfilUsuario(this.nombre);

  /// Nombre legible que se muestra en la interfaz.
  final String nombre;

  /// Convierte el valor almacenado en almacenamiento seguro al perfil
  /// correspondiente. Ante cualquier valor desconocido se usa el perfil con
  /// menos privilegios.
  static PerfilUsuario desdeJson(dynamic valor) {
    final texto = valor?.toString().toLowerCase() ?? '';
    if (texto == 'administrador' || texto == 'admin') {
      return PerfilUsuario.administrador;
    }
    return PerfilUsuario.tecnico;
  }
}

/// Usuario autenticado en la sesión actual.
class Usuario {
  final String username;
  final PerfilUsuario perfil;

  const Usuario({required this.username, required this.perfil});
}
