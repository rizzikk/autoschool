import 'package:autoschool_client/core/api_exceptions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('mapHttpError: ответ сервера → исключение предметной области', () {
    test('400 с ошибками полей → ValidationException (вид 422)', () {
      final e = mapHttpError(400, {
        'message': 'Failed to create record.',
        'data': {
          'plate': {'code': 'validation_invalid_format', 'message': 'Invalid'},
          'model': {
            'code': 'validation_required',
            'message': 'Cannot be blank.'
          },
        },
      });
      expect(e, isA<ValidationException>());
      final errors = (e as ValidationException).errors;
      expect(errors['plate'], 'Неверный формат значения');
      expect(errors['model'], 'Обязательное поле');
    });

    test('русское сообщение серверной проверки показывается как есть', () {
      final e = mapHttpError(400, {
        'data': {
          'ends_at': {
            'code': 'too_short',
            'message': 'Занятие слишком короткое.'
          }
        }
      }) as ValidationException;
      expect(e.errors['ends_at'], 'Занятие слишком короткое.');
    });

    test('409 → ConflictException с полем, к которому относится конфликт', () {
      final e = mapHttpError(409, {
        'message': 'Инструктор в это время занят другим занятием.',
        'data': {
          'instructor': {'code': 'busy', 'message': 'Инструктор занят.'}
        },
      });
      expect(e, isA<ConflictException>());
      expect(
          (e as ConflictException).errors['instructor'], 'Инструктор занят.');
      expect(e.message, contains('занят'));
    });

    test('удаление записи со ссылками → понятный конфликт', () {
      final e = mapHttpError(400, {
        'message':
            'Failed to delete record. Make sure that the record is not part of a required relation reference.'
      });
      expect(e, isA<ConflictException>());
      expect(e.message, contains('на неё ссылаются'));
    });

    test('401, 403, 404 и 5xx', () {
      expect(mapHttpError(401, null), isA<UnauthorizedException>());
      expect(mapHttpError(403, null), isA<ForbiddenException>());
      expect(mapHttpError(404, null), isA<NotFoundException>());
      expect(mapHttpError(500, null), isA<ServerException>());
      expect(mapHttpError(503, null).message, contains('503'));
    });

    test('400 без полей — общий BadRequest', () {
      expect(mapHttpError(400, {'message': 'bad'}), isA<BadRequestException>());
    });
  });

  group('translateFieldError', () {
    test('известные коды переводятся, неизвестный даёт общий текст', () {
      expect(translateFieldError('validation_not_unique', 'x'),
          'Такое значение уже используется');
      expect(translateFieldError('validation_invalid_email', 'x'),
          'Некорректный адрес почты');
      expect(translateFieldError('странный_код', 'x'), 'Недопустимое значение');
    });
  });
}
