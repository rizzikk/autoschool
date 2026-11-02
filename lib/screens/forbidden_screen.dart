import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../auth/auth_notifier.dart';
import '../router/locations.dart';
import '../widgets/state_views.dart';

class ForbiddenScreen extends StatelessWidget {
  const ForbiddenScreen({super.key, this.from, this.need});

  final String? from;

  final String? need;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthNotifier>();
    final role = auth.user?.role;
    final target = from == null ? 'Этот раздел' : 'Адрес $from';
    final needText = need == null ? '' : ' Нужно право: «$need».';
    return Scaffold(
      appBar: AppBar(title: const Text('Нет доступа')),
      body: MessageView(
        icon: Icons.lock_outline,
        iconColor: Theme.of(context).colorScheme.error,
        title: 'Доступ запрещён',
        message:
            '$target недоступен для роли «${role?.label ?? '—'}».$needText',
        action: Wrap(
          spacing: 12,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            FilledButton.icon(
              onPressed: () => context.go(homePath),
              icon: const Icon(Icons.home_outlined),
              label: const Text('На главную'),
            ),
            OutlinedButton.icon(
              onPressed: () => auth.logout(),
              icon: const Icon(Icons.switch_account),
              label: const Text('Войти под другой учётной записью'),
            ),
          ],
        ),
      ),
    );
  }
}
