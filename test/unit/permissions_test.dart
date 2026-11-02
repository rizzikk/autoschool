import 'package:autoschool_client/auth/permissions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('права на операции над коллекциями', () {
    test('администратор может всё над каждой коллекцией', () {
      for (final collection in entityAccess.keys) {
        for (final op in EntityOp.values) {
          expect(canEntity(Role.admin, collection, op), isTrue,
              reason: '$collection / ${op.label}');
        }
      }
    });

    test('курсант только просматривает справочники и не удаляет ничего', () {
      for (final c in ['categories', 'cars', 'instructors', 'groups']) {
        expect(canEntity(Role.cadet, c, EntityOp.view), isTrue);
        expect(canEntity(Role.cadet, c, EntityOp.create), isFalse);
        expect(canEntity(Role.cadet, c, EntityOp.softDelete), isFalse);
      }
      expect(canEntity(Role.cadet, 'lessons', EntityOp.hardDelete), isFalse);
    });

    test('курсант правит свою анкету, но не создаёт чужие', () {
      expect(canEntity(Role.cadet, 'cadets', EntityOp.edit), isTrue);
      expect(canEntity(Role.cadet, 'cadets', EntityOp.create), isFalse);
    });

    test('инструктор ведёт занятия и экзамены, но не видит платежи', () {
      expect(canEntity(Role.instructor, 'lessons', EntityOp.edit), isTrue);
      expect(canEntity(Role.instructor, 'exams', EntityOp.create), isTrue);
      expect(canEntity(Role.instructor, 'payments', EntityOp.view), isFalse);
      expect(
          canEntity(Role.instructor, 'lessons', EntityOp.softDelete), isFalse);
    });

    test('учётные записи пользователей — только у администратора', () {
      expect(canEntity(Role.admin, 'users', EntityOp.view), isTrue);
      expect(canEntity(Role.instructor, 'users', EntityOp.view), isFalse);
      expect(canEntity(Role.cadet, 'users', EntityOp.view), isFalse);
    });

    test('не вошедший пользователь не может ничего', () {
      expect(canEntity(null, 'categories', EntityOp.view), isFalse);
      expect(can(null, Permission.viewSchedule), isFalse);
    });

    test('неизвестная коллекция закрыта для всех', () {
      expect(canEntity(Role.admin, 'secrets', EntityOp.view), isFalse);
    });
  });

  group('особые права', () {
    test('запись на вождение — только курсант', () {
      expect(can(Role.cadet, Permission.bookLesson), isTrue);
      expect(can(Role.instructor, Permission.bookLesson), isFalse);
      expect(can(Role.admin, Permission.bookLesson), isFalse);
    });

    test('отчёт и пользователи — только администратор', () {
      for (final p in [Permission.viewReport, Permission.manageUsers]) {
        expect(can(Role.admin, p), isTrue);
        expect(can(Role.instructor, p), isFalse);
        expect(can(Role.cadet, p), isFalse);
      }
    });

    test('Role.parse: неизвестная роль — самая слабая', () {
      expect(Role.parse('admin'), Role.admin);
      expect(Role.parse('root'), Role.cadet);
      expect(Role.parse(null), Role.cadet);
    });
  });
}
