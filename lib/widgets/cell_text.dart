import 'package:flutter/material.dart';

class CellText extends StatelessWidget {
  const CellText(this.text,
      {super.key, this.maxWidth = 320, this.maxLines = 2});

  final String text;
  final double maxWidth;
  final int maxLines;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Tooltip(
          message: text,
          child:
              Text(text, maxLines: maxLines, overflow: TextOverflow.ellipsis),
        ),
      );
}
