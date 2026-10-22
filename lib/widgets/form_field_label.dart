import 'package:flutter/material.dart';

/// Etiqueta de un campo de formulario.
///
/// Se coloca encima del control (en lugar de usar el `labelText` del
/// `InputDecoration`) para que las etiquetas largas puedan ocupar varias
/// líneas y no se recorten con puntos suspensivos en pantallas pequeñas.
class FormFieldLabel extends StatelessWidget {
  final String label;
  final bool isRequired;

  const FormFieldLabel({
    super.key,
    required this.label,
    this.isRequired = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        isRequired ? '$label *' : label,
        style: Theme.of(context).textTheme.bodyMedium
            ?.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }
}
