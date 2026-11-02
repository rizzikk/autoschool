import 'package:flutter/material.dart';

import '../auth/permissions.dart';
import '../models/list_query.dart';
import '../models/pb_record.dart';
import '../repositories/conditions.dart';
import '../repositories/record_repository.dart';
import '../util/format.dart';

enum FieldType {
  text,
  multiline,
  email,
  phone,
  integer,
  money,
  boolean,
  select,
  relation,
  date,
  dateTime,
  password,
}

class RelationDef {
  const RelationDef(this.collection, {this.filter, this.sort});

  final String collection;

  final Cond? filter;
  final String? sort;
}

class FieldDef {
  const FieldDef(
    this.name,
    this.label,
    this.type, {
    this.required = false,
    this.min,
    this.max,
    this.pattern,
    this.patternMessage,
    this.options = const {},
    this.relation,
    this.multi = false,
    this.hint,
    this.createOnly = false,
    this.adminOnly = false,
    this.selfInstructor = false,
    this.initial,
    this.sameAs,
    this.noFuture = false,
    this.minItems = 0,
  });

  final String name;
  final String label;
  final FieldType type;
  final bool required;

  final num? min;
  final num? max;
  final String? pattern;
  final String? patternMessage;

  final Map<String, String> options;
  final RelationDef? relation;

  final bool multi;
  final String? hint;

  final bool createOnly;

  final bool adminOnly;

  final bool selfInstructor;
  final Object? initial;

  final String? sameAs;

  final bool noFuture;

  final int minItems;
}

class ColumnDef {
  const ColumnDef(this.label, this.text,
      {this.sortField, this.numeric = false});

  final String label;
  final String Function(PbRecord r) text;

  final String? sortField;
  final bool numeric;
}

enum FilterKind { select, relation, dateFrom, dateTo }

class FilterDef {
  const FilterDef(
    this.key,
    this.label,
    this.kind, {
    String? field,
    this.options = const {},
    this.relation,
    this.multi = false,
    this.dateTime = false,
  }) : field = field ?? key;

  final String key;
  final String label;
  final FilterKind kind;

  final String field;
  final Map<String, String> options;
  final RelationDef? relation;

  final bool multi;

  final bool dateTime;
}

class RowAction {
  const RowAction({
    required this.label,
    required this.icon,
    required this.visible,
    required this.run,
    this.confirm,
    this.success = 'Готово',
  });

  final String label;
  final IconData icon;
  final bool Function(Role role, PbRecord r) visible;
  final Future<void> Function(RecordRepository repo, PbRecord r) run;

  final String? confirm;
  final String success;
}

class RelatedDef {
  const RelatedDef(this.title, this.collection, this.field, {this.sort});

  final String title;
  final String collection;

  final String field;
  final String? sort;
}

typedef BeforeSave = Future<void> Function(
    RecordRepository repo, Map<String, dynamic> body, String? id);

class EntityDef {
  EntityDef({
    required this.collection,
    required this.path,
    required this.singular,
    required this.plural,
    required this.accusative,
    required this.icon,
    required this.fields,
    required this.columns,
    required this.titleOf,
    this.subtitleOf,
    this.searchFields = const [],
    this.filters = const [],
    this.defaultSort = 'created',
    this.defaultAscending = false,
    this.expand = '',
    this.actions = const [],
    this.related = const [],
    this.beforeSave,
    this.softDelete = true,
    this.description = '',
    this.cadetLabel,
  });

  final String collection;

  final String path;
  final String singular;
  final String plural;

  final String accusative;
  final IconData icon;
  final List<FieldDef> fields;
  final List<ColumnDef> columns;
  final String Function(PbRecord r) titleOf;
  final String Function(PbRecord r)? subtitleOf;
  final List<String> searchFields;
  final List<FilterDef> filters;
  final String defaultSort;
  final bool defaultAscending;
  final String expand;
  final List<RowAction> actions;
  final List<RelatedDef> related;
  final BeforeSave? beforeSave;

  final bool softDelete;
  final String description;

  final String? cadetLabel;

  Set<String> get sortFields => {
        for (final c in columns)
          if (c.sortField != null) c.sortField!
      };

  FieldDef? field(String name) {
    for (final f in fields) {
      if (f.name == name) return f;
    }
    return null;
  }

  Cond? buildCond(ListQuery q, {required bool canSeeDeleted}) {
    final parts = <Cond>[];
    if (softDelete) {
      final mode = canSeeDeleted ? q.deleted : DeletedMode.active;
      if (mode == DeletedMode.active) parts.add(const Eq('deleted', false));
      if (mode == DeletedMode.only) parts.add(const Eq('deleted', true));
    }
    final text = q.search.trim();
    if (text.isNotEmpty && searchFields.isNotEmpty) {
      parts.add(Or([for (final f in searchFields) Like(f, text)]));
    }
    for (final f in filters) {
      final v = q.filters[f.key];
      if (v == null || v.isEmpty) continue;
      switch (f.kind) {
        case FilterKind.select:
        case FilterKind.relation:
          parts.add(f.multi ? Has(f.field, v) : Eq(f.field, v));
        case FilterKind.dateFrom:
          final d = DateTime.tryParse(v);
          if (d == null) continue;
          parts.add(Gte(
              f.field, f.dateTime ? toPbDateTime(dayStart(d)) : toPbDate(d)));
        case FilterKind.dateTo:
          final d = DateTime.tryParse(v);
          if (d == null) continue;
          parts.add(Lte(
              f.field,
              f.dateTime
                  ? toPbDateTime(DateTime(d.year, d.month, d.day, 23, 59, 59))
                  : toPbDate(d)));
      }
    }
    return allOf(parts);
  }

  ListQuery queryFromParams(Map<String, String> params) => ListQuery.fromParams(
        params,
        sortFields: sortFields,
        filterKeys: {for (final f in filters) f.key},
        defaultSort: defaultSort,
        defaultAscending: defaultAscending,
      );

  List<FieldDef> formFields({required bool isNew, required Role? role}) => [
        for (final f in fields)
          if ((isNew || !f.createOnly) && (!f.adminOnly || role == Role.admin))
            f,
      ];
}
