import 'package:flutter_test/flutter_test.dart';

import 'package:app_productores_ra/models/usuario.dart';

void main() {
  group('PerfilUsuario', () {
    test('convierte los valores almacenados a perfiles', () {
      expect(
        PerfilUsuario.desdeJson('administrador'),
        PerfilUsuario.administrador,
      );
      expect(
        PerfilUsuario.desdeJson('Administrador'),
        PerfilUsuario.administrador,
      );
      expect(
        PerfilUsuario.desdeJson('tecnico'),
        PerfilUsuario.tecnico,
      );
      expect(PerfilUsuario.desdeJson('Tecnico'), PerfilUsuario.tecnico);
    });

    test('usa el perfil de menor privilegio para valores desconocidos', () {
      expect(PerfilUsuario.desdeJson(null), PerfilUsuario.tecnico);
      expect(PerfilUsuario.desdeJson('otro'), PerfilUsuario.tecnico);
    });

    test('expone el nombre legible de cada perfil', () {
      expect(PerfilUsuario.administrador.nombre, 'Administrador');
      expect(PerfilUsuario.tecnico.nombre, 'Tecnico');
    });
  });
}
