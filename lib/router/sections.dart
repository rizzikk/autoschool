import 'package:flutter/material.dart';

import '../auth/auth_notifier.dart';
import '../auth/permissions.dart';
import '../domain/entities.dart';
import '../domain/entity_def.dart';
import 'locations.dart';

class AppSection {
  const AppSection(
    this.path,
    this.icon,
    this.label,
    this.description, {
    this.permission,
    this.collection,
    this.cadetLabel,
  });

  final String path;
  final IconData icon;
  final String label;
  final String description;
  final Permission? permission;
  final String? collection;

  final String? cadetLabel;

  String labelFor(Role? role) =>
      role == Role.cadet ? (cadetLabel ?? label) : label;

  bool visibleFor(Role? role) {
    if (permission != null) return can(role, permission!);
    if (collection != null) return canEntity(role, collection!, EntityOp.view);
    return role != null;
  }
}

final List<AppSection> appSections = [
  const AppSection(
      homePath, Icons.home_outlined, 'Главная', 'Сводка и ближайшие занятия'),
  const AppSection(schedulePath, Icons.calendar_month, 'Расписание',
      'Занятия недели по дням',
      permission: Permission.viewSchedule),
  const AppSection(bookPath, Icons.edit_calendar, 'Запись на вождение',
      'Выбор инструктора, автомобиля и свободного времени',
      permission: Permission.bookLesson),
  const AppSection(progressPath, Icons.trending_up, 'Прогресс',
      'Часы вождения, экзамены, допуск к итоговому экзамену',
      permission: Permission.viewProgress, cadetLabel: 'Мой прогресс'),
  _entity(lessonsDef, 'Занятия'),
  _entity(cadetsDef, 'Курсанты', cadetLabel: 'Мой профиль'),
  _entity(groupsDef, 'Группы'),
  _entity(examsDef, 'Экзамены'),
  _entity(medicalDef, 'Мед. справки'),
  _entity(instructorsDef, 'Инструкторы'),
  _entity(carsDef, 'Автомобили'),
  _entity(categoriesDef, 'Категории'),
  _entity(paymentsDef, 'Платежи', cadetLabel: 'Мои платежи'),
  const AppSection(reportPath, Icons.insights, 'Отчёт',
      'Показатели школы за период, диаграммы, выгрузка в CSV',
      permission: Permission.viewReport),
  _entity(usersDef, 'Пользователи', permissionOverride: Permission.manageUsers),
];

AppSection _entity(EntityDef def, String label,
        {String? cadetLabel, Permission? permissionOverride}) =>
    AppSection(
      def.path,
      def.icon,
      label,
      def.description,
      collection: permissionOverride == null ? def.collection : null,
      permission: permissionOverride,
      cadetLabel: cadetLabel,
    );

List<AppSection> sectionsFor(AuthNotifier auth) => [
      for (final s in appSections)
        if (s.visibleFor(auth.role)) s,
    ];

AppSection? sectionOf(String location, List<AppSection> sections) {
  AppSection? best;
  for (final s in sections) {
    final match = s.path == homePath
        ? location == homePath
        : location == s.path || location.startsWith('${s.path}/');
    if (match && (best == null || s.path.length > best.path.length)) best = s;
  }
  return best;
}
