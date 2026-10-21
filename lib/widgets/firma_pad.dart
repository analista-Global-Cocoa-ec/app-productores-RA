import 'dart:convert';

import 'package:flutter/material.dart';

/// Área para dibujar una firma con el dedo o el mouse.
///
/// La firma se guarda como un JSON de trazos, donde cada punto es una
/// coordenada normalizada (0..1) respecto al tamaño del recuadro, de modo
/// que puede volver a dibujarse a cualquier escala.
class FirmaPad extends StatefulWidget {
  final String? initialValue;
  final ValueChanged<String>? onChanged;
  final double height;

  const FirmaPad({
    super.key,
    this.initialValue,
    this.onChanged,
    this.height = 180,
  });

  @override
  State<FirmaPad> createState() => _FirmaPadState();
}

class _FirmaPadState extends State<FirmaPad> {
  final List<List<Offset>> _trazos = [];
  List<Offset>? _trazoActual;
  bool _hayTinta = false;

  @override
  void initState() {
    super.initState();
    _cargarDesdeValor(widget.initialValue);
  }

  void _cargarDesdeValor(String? valor) {
    if (valor == null || valor.trim().isEmpty) return;
    try {
      final decodificado = jsonDecode(valor);
      if (decodificado is! List) return;
      for (final trazo in decodificado) {
        if (trazo is! List) continue;
        final puntos = <Offset>[];
        for (final punto in trazo) {
          if (punto is List && punto.length >= 2) {
            puntos.add(
              Offset(
                (punto[0] as num).toDouble(),
                (punto[1] as num).toDouble(),
              ),
            );
          }
        }
        if (puntos.isNotEmpty) _trazos.add(puntos);
      }
      _hayTinta = _trazos.isNotEmpty;
    } catch (_) {
      // Valor inválido: se ignora y se muestra el recuadro vacío.
    }
  }

  void _notificarCambio() {
    final datos = _trazos
        .map(
          (trazo) => trazo
              .map(
                (punto) => [
                  double.parse(punto.dx.toStringAsFixed(5)),
                  double.parse(punto.dy.toStringAsFixed(5)),
                ],
              )
              .toList(),
        )
        .toList();
    widget.onChanged?.call(jsonEncode(datos));
  }

  void _limpiar() {
    setState(() {
      _trazos.clear();
      _trazoActual = null;
      _hayTinta = false;
    });
    _notificarCambio();
  }

  Offset _normalizar(Offset local, Size size) {
    if (size.width <= 0 || size.height <= 0) return Offset.zero;
    return Offset(
      (local.dx / size.width).clamp(0.0, 1.0),
      (local.dy / size.height).clamp(0.0, 1.0),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: widget.height,
          decoration: BoxDecoration(
            color: colorScheme.surface,
            border: Border.all(color: colorScheme.outline),
            borderRadius: BorderRadius.circular(8),
          ),
          clipBehavior: Clip.antiAlias,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = Size(constraints.maxWidth, constraints.maxHeight);
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: (detalles) {
                  setState(() {
                    _trazoActual = [_normalizar(detalles.localPosition, size)];
                    _trazos.add(_trazoActual!);
                    _hayTinta = true;
                  });
                },
                onPanUpdate: (detalles) {
                  if (_trazoActual == null) return;
                  setState(() {
                    _trazoActual!.add(_normalizar(detalles.localPosition, size));
                  });
                  _notificarCambio();
                },
                onPanEnd: (_) {
                  _trazoActual = null;
                  _notificarCambio();
                },
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _FirmaPainter(
                          trazos: _trazos,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ),
                    if (!_hayTinta)
                      Center(
                        child: Text(
                          'Firme aquí',
                          style: TextStyle(
                            color: colorScheme.onSurfaceVariant,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: _hayTinta ? _limpiar : null,
            icon: const Icon(Icons.delete_outline, size: 18),
            label: const Text('Limpiar firma'),
          ),
        ),
      ],
    );
  }
}

class _FirmaPainter extends CustomPainter {
  final List<List<Offset>> trazos;
  final Color color;

  _FirmaPainter({required this.trazos, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    for (final trazo in trazos) {
      if (trazo.isEmpty) continue;
      final path = Path()
        ..moveTo(trazo.first.dx * size.width, trazo.first.dy * size.height);
      for (final punto in trazo.skip(1)) {
        path.lineTo(punto.dx * size.width, punto.dy * size.height);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _FirmaPainter oldDelegate) => true;
}
