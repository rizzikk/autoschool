import 'package:flutter/material.dart';

import '../models/page_result.dart';
import '../models/query_params.dart';

class PaginationBar extends StatelessWidget {
  final PageResult<Object?> result;
  final int size;
  final ValueChanged<int> onPage;
  final ValueChanged<int> onSize;

  const PaginationBar({
    super.key,
    required this.result,
    required this.size,
    required this.onPage,
    required this.onSize,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final from = result.items.isEmpty ? 0 : (result.page - 1) * result.size + 1;
    final to = result.items.isEmpty ? 0 : from + result.items.length - 1;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: theme.dividerColor)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 16,
          runSpacing: 4,
          children: [
            Text('Записи $from–$to из ${result.total}'),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Первая страница',
                  icon: const Icon(Icons.first_page),
                  onPressed: result.hasPrevious ? () => onPage(1) : null,
                ),
                IconButton(
                  tooltip: 'Предыдущая страница',
                  icon: const Icon(Icons.chevron_left),
                  onPressed:
                      result.hasPrevious ? () => onPage(result.page - 1) : null,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    'Стр. ${result.page} из ${result.totalPages}',
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                IconButton(
                  tooltip: 'Следующая страница',
                  icon: const Icon(Icons.chevron_right),
                  onPressed:
                      result.hasNext ? () => onPage(result.page + 1) : null,
                ),
                IconButton(
                  tooltip: 'Последняя страница',
                  icon: const Icon(Icons.last_page),
                  onPressed:
                      result.hasNext ? () => onPage(result.totalPages) : null,
                ),
              ],
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('На странице:'),
                const SizedBox(width: 8),
                DropdownButton<int>(
                  value:
                      allowedPageSizes.contains(size) ? size : defaultPageSize,
                  items: [
                    for (final s in allowedPageSizes)
                      DropdownMenuItem(value: s, child: Text('$s')),
                  ],
                  onChanged: (value) {
                    if (value != null && value != size) onSize(value);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
