import 'package:flutter/material.dart';

class DeletedBadge extends StatelessWidget {
  const DeletedBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        'удалено',
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(color: scheme.onErrorContainer),
      ),
    );
  }
}

class TitleWithBadge extends StatelessWidget {
  final String text;
  final bool deleted;

  const TitleWithBadge({super.key, required this.text, required this.deleted});

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Text(text, maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
          if (deleted) const DeletedBadge(),
        ],
      );
}
