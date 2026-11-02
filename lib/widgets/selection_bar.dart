import 'package:flutter/material.dart';

class SelectionBar extends StatelessWidget {
  final int count;
  final VoidCallback onClear;
  final List<Widget> actions;

  const SelectionBar({
    super.key,
    required this.count,
    required this.onClear,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Icon(Icons.check_box, color: scheme.onSecondaryContainer),
            Text(
              'Выбрано: $count',
              style: TextStyle(
                color: scheme.onSecondaryContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
            TextButton(onPressed: onClear, child: const Text('Снять')),
            ...actions,
          ],
        ),
      ),
    );
  }
}
