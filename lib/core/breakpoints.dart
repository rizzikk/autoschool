import 'package:flutter/widgets.dart';

enum ScreenSize { compact, medium, expanded }

const double mediumBreakpoint = 600;

const double expandedBreakpoint = 1200;

const double contentMaxWidth = 1400;

ScreenSize screenSizeFor(double width) {
  if (width < mediumBreakpoint) return ScreenSize.compact;
  if (width < expandedBreakpoint) return ScreenSize.medium;
  return ScreenSize.expanded;
}

ScreenSize screenSizeOf(BuildContext context) =>
    screenSizeFor(MediaQuery.sizeOf(context).width);

T byScreen<T>(
  BuildContext context, {
  required T compact,
  T? medium,
  T? expanded,
}) {
  return switch (screenSizeOf(context)) {
    ScreenSize.compact => compact,
    ScreenSize.medium => medium ?? compact,
    ScreenSize.expanded => expanded ?? medium ?? compact,
  };
}

class ContentFrame extends StatelessWidget {
  const ContentFrame(
      {super.key, required this.child, this.maxWidth = contentMaxWidth});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: child,
        ),
      );
}
