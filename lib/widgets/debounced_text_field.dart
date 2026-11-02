import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class DebouncedTextField extends StatefulWidget {
  final String value;
  final ValueChanged<String> onChanged;
  final String? label;
  final String? hint;
  final IconData? icon;
  final double? width;
  final bool digitsOnly;
  final int? maxLength;
  final Duration delay;

  const DebouncedTextField({
    super.key,
    required this.value,
    required this.onChanged,
    this.label,
    this.hint,
    this.icon,
    this.width,
    this.digitsOnly = false,
    this.maxLength,
    this.delay = const Duration(milliseconds: 400),
  });

  @override
  State<DebouncedTextField> createState() => _DebouncedTextFieldState();
}

class _DebouncedTextFieldState extends State<DebouncedTextField> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.value);
  Timer? _timer;

  @override
  void didUpdateWidget(DebouncedTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value &&
        widget.value != _controller.text.trim()) {
      _timer?.cancel();
      _controller.text = widget.value;
    }
  }

  void _onChanged(String text) {
    _timer?.cancel();
    _timer = Timer(widget.delay, () => _emit(text));
  }

  void _emit(String text) {
    _timer?.cancel();
    final value = text.trim();
    if (value != widget.value) widget.onChanged(value);
  }

  void _clear() {
    _controller.clear();
    _emit('');
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final icon = widget.icon;
    final maxLength = widget.maxLength;
    return SizedBox(
      width: widget.width,
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: _controller,
        builder: (context, value, child) => TextField(
          controller: _controller,
          onChanged: _onChanged,
          onSubmitted: _emit,
          keyboardType:
              widget.digitsOnly ? TextInputType.number : TextInputType.text,
          inputFormatters: [
            if (widget.digitsOnly) FilteringTextInputFormatter.digitsOnly,
            if (maxLength != null) LengthLimitingTextInputFormatter(maxLength),
          ],
          decoration: InputDecoration(
            isDense: true,
            border: const OutlineInputBorder(),
            labelText: widget.label,
            hintText: widget.hint,
            prefixIcon: icon == null ? null : Icon(icon),
            suffixIcon: value.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Очистить',
                    icon: const Icon(Icons.clear),
                    onPressed: _clear,
                  ),
          ),
        ),
      ),
    );
  }
}
