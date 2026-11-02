import 'package:flutter/material.dart';

import '../core/api_exceptions.dart';

Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Удалить',
  bool destructive = true,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      final scheme = Theme.of(dialogContext).colorScheme;
      return AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            style: destructive
                ? FilledButton.styleFrom(
                    backgroundColor: scheme.error,
                    foregroundColor: scheme.onError,
                  )
                : null,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      );
    },
  );
  return result ?? false;
}

Future<bool> runWithFeedback(
  BuildContext context,
  Future<void> Function() action, {
  required String success,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    await action();
    messenger.showSnackBar(SnackBar(content: Text(success)));
    return true;
  } catch (e) {
    if (context.mounted) await showApiError(context, e, messenger: messenger);
    return false;
  }
}

Future<void> showApiError(
  BuildContext context,
  Object error, {
  String prefix = 'Ошибка',
  ScaffoldMessengerState? messenger,
}) async {
  if (error is ForbiddenException) {
    await showMessageDialog(
      context,
      title: 'Недостаточно прав',
      message: 'Сервер отклонил операцию (код 403): ${error.message}.',
      icon: Icons.gpp_bad_outlined,
    );
    return;
  }
  (messenger ?? ScaffoldMessenger.of(context))
      .showSnackBar(SnackBar(content: Text('$prefix: $error')));
}

Future<void> showMessageDialog(
  BuildContext context, {
  required String title,
  required String message,
  IconData icon = Icons.block,
}) =>
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: Icon(icon, color: Theme.of(dialogContext).colorScheme.error),
        title: Text(title),
        content: Text(message),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Понятно'),
          ),
        ],
      ),
    );

String formatDateTime(DateTime d) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.day)}.${two(d.month)}.${d.year} ${two(d.hour)}:${two(d.minute)}';
}
