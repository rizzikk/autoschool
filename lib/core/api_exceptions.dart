import 'package:dio/dio.dart';

sealed class ApiException implements Exception {
  const ApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class NetworkException extends ApiException {
  const NetworkException(
      [super.message = 'Сервер недоступен. Проверьте соединение.']);
}

class CancelledException extends ApiException {
  const CancelledException() : super('Запрос отменён');
}

class BadRequestException extends ApiException {
  const BadRequestException([super.message = 'Некорректный запрос.']);
}

class UnauthorizedException extends ApiException {
  const UnauthorizedException([super.message = 'Требуется вход в систему.']);
}

class ForbiddenException extends ApiException {
  const ForbiddenException(
      [super.message = 'Недостаточно прав для этого действия.']);
}

class NotFoundException extends ApiException {
  const NotFoundException([super.message = 'Запись не найдена.']);
}

class ConflictException extends ApiException {
  const ConflictException(super.message, [this.errors = const {}]);

  final Map<String, String> errors;
}

class ValidationException extends ApiException {
  const ValidationException(super.message, this.errors);

  final Map<String, String> errors;
}

class ServerException extends ApiException {
  const ServerException(
      [super.message = 'Ошибка на сервере. Попробуйте позже.']);
}

final _cyrillic = RegExp(r'[А-Яа-яЁё]');

String translateFieldError(String? code, String? message) {
  if (message != null && _cyrillic.hasMatch(message)) return message;
  return switch (code) {
    'validation_required' || 'validation_is_required' => 'Обязательное поле',
    'validation_not_unique' => 'Такое значение уже используется',
    'validation_invalid_email' => 'Некорректный адрес почты',
    'validation_min_text_constraint' => 'Слишком короткое значение',
    'validation_max_text_constraint' => 'Слишком длинное значение',
    'validation_length_out_of_range' => 'Недопустимая длина значения',
    'validation_min_number_constraint' ||
    'validation_max_number_constraint' ||
    'validation_min_greater_equal_than_required' ||
    'validation_max_less_equal_than_required' =>
      'Число вне допустимых пределов',
    'validation_invalid_format' ||
    'validation_match_invalid' ||
    'validation_invalid_value' =>
      'Неверный формат значения',
    'validation_values_mismatch' => 'Значения не совпадают',
    'validation_invalid_date' ||
    'validation_invalid_datetime' =>
      'Некорректная дата',
    'validation_missing_rel_records' => 'Связанная запись не найдена',
    _ => 'Недопустимое значение',
  };
}

Map<String, String> _fieldErrors(dynamic body) {
  if (body is! Map || body['data'] is! Map) return const {};
  final result = <String, String>{};
  (body['data'] as Map).forEach((field, error) {
    if (error is Map) {
      result['$field'] = translateFieldError(
          error['code'] as String?, error['message'] as String?);
    }
  });
  return result;
}

ApiException mapHttpError(int status, dynamic body) {
  final message = (body is Map && body['message'] is String)
      ? body['message'] as String
      : null;
  final fields = _fieldErrors(body);
  return switch (status) {
    400 ||
    422 when fields.isNotEmpty =>
      ValidationException('Проверьте значения полей формы.', fields),
    400 when message != null && message.contains('required relation') =>
      const ConflictException(
          'Запись нельзя удалить: на неё ссылаются другие записи '
          '(занятия, платежи, экзамены). Используйте «в корзину».'),
    400 || 422 => BadRequestException(
        _cyrillic.hasMatch(message ?? '') ? message! : 'Некорректный запрос.'),
    401 => UnauthorizedException(_cyrillic.hasMatch(message ?? '')
        ? message!
        : 'Требуется вход в систему.'),
    403 => const ForbiddenException(),
    404 => const NotFoundException(),
    409 => ConflictException(
        _cyrillic.hasMatch(message ?? '')
            ? message!
            : 'Операция невозможна: конфликт данных.',
        fields),
    _ => ServerException('Ошибка на сервере (код $status).'),
  };
}

ApiException mapDioError(DioException e) {
  final existing = e.error;
  if (existing is ApiException) return existing;
  final response = e.response;
  if (e.type == DioExceptionType.badResponse && response != null) {
    return mapHttpError(response.statusCode ?? 0, response.data);
  }
  return switch (e.type) {
    DioExceptionType.connectionTimeout ||
    DioExceptionType.sendTimeout ||
    DioExceptionType.receiveTimeout =>
      const NetworkException('Сервер не ответил вовремя.'),
    DioExceptionType.connectionError => const NetworkException(
        'Не удалось соединиться с сервером. Если сервер запущен, откройте '
        'консоль браузера и проверьте наличие ошибки CORS.',
      ),
    DioExceptionType.cancel => const CancelledException(),
    _ => const NetworkException(
        'Не удалось выполнить запрос. Если сервер запущен, откройте '
        'консоль браузера и проверьте наличие ошибки CORS.',
      ),
  };
}

Future<T> guard<T>(Future<T> Function() action) async {
  try {
    return await action();
  } on DioException catch (e) {
    throw mapDioError(e);
  }
}
