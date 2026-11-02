import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../widgets/state_views.dart';

class NotFoundScreen extends StatelessWidget {
  final String location;

  const NotFoundScreen({super.key, required this.location});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Страница не найдена')),
        body: MessageView(
          icon: Icons.explore_off,
          title: 'Нет такой страницы',
          message: 'Адрес «$location» не существует.',
          action: FilledButton(
            onPressed: () => context.go('/'),
            child: const Text('На главную'),
          ),
        ),
      );
}
