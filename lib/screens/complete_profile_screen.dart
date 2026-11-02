import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../auth/auth_notifier.dart';
import '../domain/entities.dart';
import '../forms/dynamic_form.dart';
import '../router/locations.dart';
import '../util/format.dart';

class CompleteProfileScreen extends StatelessWidget {
  const CompleteProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthNotifier>();
    final user = auth.user;
    final fields = [
      for (final name in const ['full_name', 'birth_date', 'phone', 'category'])
        cadetsDef.field(name)!,
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Заполните анкету курсанта'),
        actions: [
          TextButton.icon(
            onPressed: () => auth.logout(),
            icon: const Icon(Icons.logout),
            label: const Text('Выйти'),
          ),
        ],
      ),
      body: user == null
          ? const SizedBox.shrink()
          : DynamicForm(
              def: cadetsDef,
              fields: fields,
              fixedBody: {
                'user': user.id,
                'status': 'studying',
                'enrolled_at': toPbDate(DateTime.now()),
              },
              initialValues: {'full_name': user.name},
              submitLabel: 'Сохранить анкету',
              onCancel: () => auth.logout(),
              onSaved: (_) async {
                await auth.reloadProfile();
                if (context.mounted) context.go(homePath);
              },
            ),
    );
  }
}
