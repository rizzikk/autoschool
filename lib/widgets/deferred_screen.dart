import 'package:flutter/material.dart';

import 'state_views.dart';

bool assumeDeferredLibrariesLoaded = false;

class DeferredScreen extends StatefulWidget {
  const DeferredScreen({super.key, required this.load, required this.builder});

  final Future<void> Function() load;
  final Widget Function() builder;

  @override
  State<DeferredScreen> createState() => _DeferredScreenState();
}

class _DeferredScreenState extends State<DeferredScreen> {
  late Future<void> _future = _start();

  Future<void> _start() =>
      assumeDeferredLibrariesLoaded ? Future<void>.value() : widget.load();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            body: ErrorView(
              message: 'Не удалось загрузить раздел приложения. '
                  'Проверьте соединение.',
              onRetry: () => setState(() => _future = _start()),
            ),
          );
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(body: LoadingView());
        }
        return widget.builder();
      },
    );
  }
}
