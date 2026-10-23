import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Utilidades compartidas por la capa de sincronización con Firestore.
class SyncUtils {
  SyncUtils._();

  /// Genera el ID determinista del documento en la colección
  /// `formularios-fincas` usando el ID estable de la finca.
  static String docIdPara(String fincaId, String templateId) {
    final limpio = '${fincaId}_$templateId'.replaceAll('/', '-');
    return limpio;
  }

  /// Extrae el ID base de una plantilla a partir de la clave compuesta
  /// usada por Hive (`templateId:hashCodeFinca`).
  static String templateBaseId(String templateId) {
    final indice = templateId.lastIndexOf(':');
    return indice == -1 ? templateId : templateId.substring(0, indice);
  }

  /// Calcula un hash estable del contenido de las respuestas.
  static String hashRespuestas(Map<String, dynamic> respuestas) {
    final canonico = _canonicalizar(respuestas);
    return sha256.convert(utf8.encode(jsonEncode(canonico))).toString();
  }

  /// Calcula un hash estable de los datos generales de una finca.
  ///
  /// Se excluyen los metadatos de sincronización (ID, fechas) para comparar
  /// únicamente el contenido editable.
  static String hashFinca({
    required String codigo,
    required String canton,
    required String prefijo,
    required String estado,
    String? nombreAgricultor,
  }) {
    return hashRespuestas({
      'codigo': codigo,
      'canton': canton,
      'prefijo': prefijo,
      'estado': estado,
      'nombreAgricultor': (nombreAgricultor ?? '').trim(),
    });
  }

  /// Convierte las respuestas a tipos aceptados por Firestore.
  static Map<String, dynamic> sanitizarRespuestas(
    Map<String, dynamic> respuestas,
  ) {
    final salida = <String, dynamic>{};
    respuestas.forEach((clave, valor) {
      salida[clave] = _sanitizarValor(valor);
    });
    return salida;
  }

  static dynamic _canonicalizar(dynamic valor) {
    if (valor is Map) {
      final entradas =
          valor.entries
              .map((entrada) => MapEntry(entrada.key.toString(), entrada.value))
              .toList()
            ..sort((a, b) => a.key.compareTo(b.key));
      return {
        for (final entrada in entradas)
          entrada.key: _canonicalizar(entrada.value),
      };
    }
    if (valor is List) {
      return valor.map(_canonicalizar).toList();
    }
    if (valor is DateTime) {
      return valor.toUtc().toIso8601String();
    }
    if (valor is num || valor is String || valor is bool || valor == null) {
      return valor;
    }
    return valor.toString();
  }

  static dynamic _sanitizarValor(dynamic valor) {
    if (valor == null || valor is num || valor is String || valor is bool) {
      return valor;
    }
    if (valor is DateTime) {
      return valor.toUtc().toIso8601String();
    }
    if (valor is Map) {
      final salida = <String, dynamic>{};
      valor.forEach((clave, contenido) {
        salida[clave.toString()] = _sanitizarValor(contenido);
      });
      return salida;
    }
    if (valor is List) {
      return valor.map(_sanitizarValor).toList();
    }
    return valor.toString();
  }
}
