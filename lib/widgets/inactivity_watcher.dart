import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class InactivityWatcher extends StatefulWidget {
  const InactivityWatcher({
    super.key,
    required this.enabled,
    required this.timeout,
    required this.warning,
    required this.onTimeout,
    required this.child,
    this.onActivity,
  });

  final bool enabled;
  final Duration timeout;
  final Duration warning;
  final VoidCallback onTimeout;
  final VoidCallback? onActivity;
  final Widget child;

  @override
  State<InactivityWatcher> createState() => _InactivityWatcherState();
}

class _InactivityWatcherState extends State<InactivityWatcher> {
  Timer? _warningTimer;
  Timer? _timeoutTimer;
  Timer? _ticker;
  DateTime _deadline = DateTime.now();
  bool _warningShown = false;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
    if (widget.enabled) _restart();
  }

  @override
  void didUpdateWidget(InactivityWatcher oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled != oldWidget.enabled) {
      if (widget.enabled) {
        _restart();
      } else {
        _stop();
      }
    }
  }

  bool _onKey(KeyEvent event) {
    _activity();
    return false;
  }

  void _activity() {
    if (!widget.enabled) return;
    widget.onActivity?.call();
    final hadWarning = _warningShown;
    _restart();
    if (hadWarning && mounted) setState(() {});
  }

  void _restart() {
    _stop();
    _deadline = DateTime.now().add(widget.timeout);
    var warnAfter = widget.timeout - widget.warning;
    if (warnAfter.isNegative) warnAfter = Duration.zero;
    _warningTimer = Timer(warnAfter, _showWarning);
    _timeoutTimer = Timer(widget.timeout, _expire);
  }

  void _stop() {
    _warningTimer?.cancel();
    _timeoutTimer?.cancel();
    _ticker?.cancel();
    _warningShown = false;
  }

  void _showWarning() {
    if (!mounted) return;
    setState(() => _warningShown = true);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  void _expire() {
    if (mounted) setState(_stop);
    widget.onTimeout();
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    _warningTimer?.cancel();
    _timeoutTimer?.cancel();
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var left = _deadline.difference(DateTime.now());
    if (left.isNegative) left = Duration.zero;
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _activity(),
      onPointerMove: (_) => _activity(),
      onPointerHover: (_) => _activity(),
      onPointerSignal: (_) => _activity(),
      child: Stack(
        fit: StackFit.expand,
        children: [
          widget.child,
          if (_warningShown)
            Positioned.fill(
              child: _IdleWarning(
                secondsLeft: (left.inMilliseconds / 1000).ceil(),
                idleFor: widget.timeout - left,
                onContinue: _activity,
              ),
            ),
        ],
      ),
    );
  }
}

class _IdleWarning extends StatelessWidget {
  const _IdleWarning({
    required this.secondsLeft,
    required this.idleFor,
    required this.onContinue,
  });

  final int secondsLeft;
  final Duration idleFor;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final minutes = idleFor.inMinutes;
    final seconds = (idleFor.inSeconds % 60).toString().padLeft(2, '0');
    return Material(
      color: Colors.black54,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.hourglass_bottom,
                      size: 40, color: theme.colorScheme.error),
                  const SizedBox(height: 12),
                  Text('Сессия скоро завершится',
                      style: theme.textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(
                    'Нет действий $minutes:$seconds. Если ничего не делать, '
                    'выход из системы произойдёт через $secondsLeft с.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: onContinue,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Продолжить работу'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
