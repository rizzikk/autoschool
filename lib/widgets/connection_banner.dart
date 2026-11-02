import 'package:flutter/material.dart';

import '../core/connection.dart';

class ConnectionBanner extends StatelessWidget {
  const ConnectionBanner({super.key, required this.connection});

  final ConnectionNotifier connection;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: connection,
      builder: (context, _) {
        if (!connection.offline) return const SizedBox.shrink();
        final scheme = Theme.of(context).colorScheme;
        return Semantics(
          liveRegion: true,
          child: Material(
            color: scheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Wrap(
                spacing: 12,
                runSpacing: 2,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Icon(Icons.cloud_off,
                      size: 20, color: scheme.onErrorContainer),
                  Text(
                    'Нет связи с сервером. Проверяю каждые '
                    '${connection.interval.inSeconds} с, данные обновятся сами.',
                    style: TextStyle(color: scheme.onErrorContainer),
                  ),
                  TextButton(
                    onPressed: connection.checkNow,
                    child: const Text('Проверить сейчас'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
