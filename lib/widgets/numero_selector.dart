import 'package:flutter/material.dart';

/// Selector de números usando PopupMenuButton para evitar
/// el bug de DropdownButtonFormField con items dinámicos en Flutter web.
class NumeroSelector extends StatelessWidget {
  final List<int> numeros;
  final int? valorSeleccionado;
  final ValueChanged<int?> onChanged;

  const NumeroSelector({
    super.key,
    required this.numeros,
    required this.valorSeleccionado,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      onSelected: onChanged,
      itemBuilder: (context) => numeros
          .map((n) => PopupMenuItem<int>(
                value: n,
                child: Text(
                  n.toString().padLeft(3, '0'),
                  style: const TextStyle(fontSize: 16),
                ),
              ))
          .toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.numbers),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                valorSeleccionado != null
                    ? valorSeleccionado.toString().padLeft(3, '0')
                    : 'Seleccionar número...',
                style: TextStyle(
                  fontSize: 16,
                  color: valorSeleccionado != null
                      ? Theme.of(context).textTheme.bodyLarge?.color
                      : Colors.grey[600],
                ),
              ),
            ),
            const Icon(Icons.arrow_drop_down),
          ],
        ),
      ),
    );
  }
}
