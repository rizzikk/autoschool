import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/connection.dart';
import '../state/load_status.dart';

class LoadingView extends StatelessWidget {
  const LoadingView({super.key});

  @override
  Widget build(BuildContext context) => const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('Загрузка…'),
          ],
        ),
      );
}

class MessageView extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String title;
  final String message;
  final Widget? action;

  const MessageView({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.iconColor,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final action = this.action;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 64, color: iconColor ?? theme.colorScheme.outline),
              const SizedBox(height: 16),
              Text(title,
                  style: theme.textTheme.titleLarge,
                  textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(message,
                  style: theme.textTheme.bodyMedium,
                  textAlign: TextAlign.center),
              if (action != null) ...[const SizedBox(height: 20), action],
            ],
          ),
        ),
      ),
    );
  }
}

class ErrorView extends StatefulWidget {
  final String message;
  final VoidCallback onRetry;

  const ErrorView({super.key, required this.message, required this.onRetry});

  @override
  State<ErrorView> createState() => _ErrorViewState();
}

class _ErrorViewState extends State<ErrorView> {
  ConnectionNotifier? _connection;
  int _seen = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = Provider.of<ConnectionNotifier?>(context, listen: false);
    if (next == _connection) return;
    _connection?.removeListener(_onConnection);
    _connection = next;
    _seen = next?.recoveries ?? 0;
    next?.addListener(_onConnection);
  }

  void _onConnection() {
    final connection = _connection;
    if (connection == null) return;
    if (connection.recoveries != _seen) {
      _seen = connection.recoveries;
      widget.onRetry();
    } else if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _connection?.removeListener(_onConnection);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final offline = _connection?.offline ?? false;
    return MessageView(
      icon: offline ? Icons.wifi_off : Icons.cloud_off,
      iconColor: Theme.of(context).colorScheme.error,
      title: offline ? 'Нет связи с сервером' : 'Ошибка загрузки',
      message: offline
          ? '${widget.message}\n\nКак только связь появится, данные '
              'загрузятся сами.'
          : widget.message,
      action: FilledButton.icon(
        onPressed: widget.onRetry,
        icon: const Icon(Icons.refresh),
        label: const Text('Повторить'),
      ),
    );
  }
}

class ListStateView extends StatelessWidget {
  final LoadStatus status;
  final String? error;
  final bool hasData;
  final String emptyTitle;
  final String emptyMessage;
  final VoidCallback onRetry;
  final VoidCallback? onResetFilters;
  final Widget child;

  const ListStateView({
    super.key,
    required this.status,
    required this.error,
    required this.hasData,
    required this.emptyTitle,
    required this.emptyMessage,
    required this.onRetry,
    required this.child,
    this.onResetFilters,
  });

  @override
  Widget build(BuildContext context) {
    final reset = onResetFilters;
    return switch (status) {
      LoadStatus.error =>
        ErrorView(message: error ?? 'Неизвестная ошибка', onRetry: onRetry),
      LoadStatus.idle ||
      LoadStatus.loading when !hasData =>
        const LoadingView(),
      LoadStatus.success when !hasData => MessageView(
          icon: Icons.search_off,
          title: emptyTitle,
          message: emptyMessage,
          action: reset == null
              ? null
              : OutlinedButton.icon(
                  onPressed: reset,
                  icon: const Icon(Icons.filter_alt_off),
                  label: const Text('Сбросить фильтры'),
                ),
        ),
      _ => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 3,
              child: status == LoadStatus.loading
                  ? const LinearProgressIndicator()
                  : null,
            ),
            Expanded(child: child),
          ],
        ),
    };
  }
}

class DetailsStateView extends StatelessWidget {
  final LoadStatus status;
  final String? error;
  final bool notFound;
  final bool hasData;
  final String notFoundMessage;
  final VoidCallback onRetry;
  final Widget Function() builder;

  const DetailsStateView({
    super.key,
    required this.status,
    required this.error,
    required this.notFound,
    required this.hasData,
    required this.notFoundMessage,
    required this.onRetry,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    if (status == LoadStatus.error) {
      return ErrorView(
          message: error ?? 'Неизвестная ошибка', onRetry: onRetry);
    }
    if (notFound) {
      return MessageView(
        icon: Icons.help_outline,
        title: 'Запись не найдена',
        message: notFoundMessage,
      );
    }
    if (!hasData) return const LoadingView();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 3,
          child: status == LoadStatus.loading
              ? const LinearProgressIndicator()
              : null,
        ),
        Expanded(child: builder()),
      ],
    );
  }
}
