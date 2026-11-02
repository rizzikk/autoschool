import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../domain/entity_def.dart';
import '../forms/dynamic_form.dart';
import '../models/pb_record.dart';
import '../repositories/record_repository.dart';
import '../router/locations.dart';
import '../state/details_notifier.dart';
import '../widgets/state_views.dart';

class EntityFormScreen extends StatelessWidget {
  const EntityFormScreen({super.key, required this.def, this.id});

  final EntityDef def;

  final String? id;

  @override
  Widget build(BuildContext context) {
    final title = id == null
        ? 'Новая запись: ${def.singular}'
        : 'Изменение: ${def.singular}';
    void back() =>
        context.go(id == null ? def.path : detailsLocation(def.path, id!));
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: BackButton(onPressed: back),
      ),
      body: id == null
          ? DynamicForm(
              def: def,
              onCancel: back,
              onSaved: (saved) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Запись создана')));
                context.go(detailsLocation(def.path, saved.id));
              },
            )
          : ChangeNotifierProvider(
              key: ValueKey('$id'),
              create: (context) {
                final repo = context.read<RecordRepository>();
                return DetailsNotifier<PbRecord>(
                    () => repo.find(def.collection, id!, expand: def.expand))
                  ..load();
              },
              child: Consumer<DetailsNotifier<PbRecord>>(
                builder: (context, n, _) => DetailsStateView(
                  status: n.status,
                  error: n.error,
                  notFound: n.notFound,
                  hasData: n.data != null,
                  notFoundMessage:
                      'Такой записи нет или у вас нет к ней доступа.',
                  onRetry: n.load,
                  builder: () => DynamicForm(
                    def: def,
                    record: n.data,
                    onCancel: back,
                    onSaved: (saved) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Изменения сохранены')));
                      context.go(detailsLocation(def.path, saved.id));
                    },
                  ),
                ),
              ),
            ),
    );
  }
}
