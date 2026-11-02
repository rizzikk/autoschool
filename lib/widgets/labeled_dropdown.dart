import 'package:flutter/material.dart';

class LabeledDropdown<V> extends StatelessWidget {
  final String label;
  final V? value;
  final Map<V, String> options;
  final ValueChanged<V?> onChanged;
  final String anyLabel;
  final double? width;

  const LabeledDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.anyLabel = 'Все',
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final effective =
        value != null && options.containsKey(value) ? value : null;
    return SizedBox(
      width: width,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          border: const OutlineInputBorder(),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<V?>(
            value: effective,
            isDense: true,
            isExpanded: true,
            items: [
              DropdownMenuItem<V?>(value: null, child: Text(anyLabel)),
              for (final e in options.entries)
                DropdownMenuItem<V?>(
                  value: e.key,
                  child: Text(e.value, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (v) {
              if (v != effective) onChanged(v);
            },
          ),
        ),
      ),
    );
  }
}
