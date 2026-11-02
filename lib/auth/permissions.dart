library;

enum Role {
  cadet('Курсант'),
  instructor('Инструктор'),
  admin('Администратор');

  const Role(this.label);
  final String label;

  static Role parse(Object? value) => switch (value) {
        'admin' => Role.admin,
        'instructor' => Role.instructor,
        _ => Role.cadet,
      };
}

enum EntityOp {
  view('просмотр'),
  create('создание'),
  edit('изменение'),
  softDelete('удаление в корзину'),
  restore('восстановление'),
  hardDelete('физическое удаление'),
  viewDeleted('просмотр удалённых');

  const EntityOp(this.label);
  final String label;
}

const _all = {
  EntityOp.view,
  EntityOp.create,
  EntityOp.edit,
  EntityOp.softDelete,
  EntityOp.restore,
  EntityOp.hardDelete,
  EntityOp.viewDeleted,
};
const _view = {EntityOp.view};

const Map<String, Map<Role, Set<EntityOp>>> entityAccess = {
  'categories': {Role.cadet: _view, Role.instructor: _view, Role.admin: _all},
  'cadets': {
    Role.cadet: {EntityOp.view, EntityOp.edit},
    Role.instructor: _view,
    Role.admin: _all,
  },
  'medical_certificates': {
    Role.cadet: _view,
    Role.instructor: _view,
    Role.admin: _all,
  },
  'instructors': {Role.cadet: _view, Role.instructor: _view, Role.admin: _all},
  'cars': {Role.cadet: _view, Role.instructor: _view, Role.admin: _all},
  'groups': {Role.cadet: _view, Role.instructor: _view, Role.admin: _all},
  'lessons': {
    Role.cadet: _view,
    Role.instructor: {EntityOp.view, EntityOp.create, EntityOp.edit},
    Role.admin: _all,
  },
  'exams': {
    Role.cadet: _view,
    Role.instructor: {EntityOp.view, EntityOp.create, EntityOp.edit},
    Role.admin: _all,
  },
  'payments': {Role.cadet: _view, Role.admin: _all},
  'users': {Role.admin: _all},
};

bool canEntity(Role? role, String collection, EntityOp op) =>
    role != null && (entityAccess[collection]?[role]?.contains(op) ?? false);

enum Permission {
  bookLesson('Запись на занятие вождением'),
  viewSchedule('Недельное расписание'),
  viewProgress('Прогресс курсанта и допуск к экзамену'),
  markLessons('Отметка результата занятия'),
  viewReport('Отчёт и выгрузка в CSV'),
  manageUsers('Управление учётными записями');

  const Permission(this.label);
  final String label;
}

const Map<Role, Set<Permission>> rolePermissions = {
  Role.cadet: {
    Permission.bookLesson,
    Permission.viewSchedule,
    Permission.viewProgress,
  },
  Role.instructor: {
    Permission.viewSchedule,
    Permission.viewProgress,
    Permission.markLessons,
  },
  Role.admin: {
    Permission.viewSchedule,
    Permission.viewProgress,
    Permission.markLessons,
    Permission.viewReport,
    Permission.manageUsers,
  },
};

bool can(Role? role, Permission permission) =>
    role != null && (rolePermissions[role]?.contains(permission) ?? false);
