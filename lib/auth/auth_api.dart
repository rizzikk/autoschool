import 'package:dio/dio.dart';

import '../core/api_exceptions.dart';
import 'app_user.dart';
import 'permissions.dart';

class AuthApi {
  AuthApi(this._dio);

  final Dio _dio;

  static Options get _public => Options(extra: {'skipAuth': true});

  AuthResult _result(dynamic data) {
    final map = data is Map ? Map<String, dynamic>.from(data) : const {};
    final record = map['record'];
    if (map['token'] is! String || record is! Map) {
      throw const ServerException('Сервер вернул неожиданный ответ при входе.');
    }
    return AuthResult(
      token: map['token'] as String,
      user: AppUser.fromRecord(Map<String, dynamic>.from(record)),
    );
  }

  Future<AuthResult> login(String email, String password) => guard(() async {
        try {
          final response = await _dio.post<dynamic>(
              '/collections/users/auth-with-password',
              data: {'identity': email, 'password': password},
              options: _public);
          return _result(response.data);
        } on ApiException catch (e) {
          if (e is BadRequestException || e is ValidationException) {
            throw const UnauthorizedException('Неверная почта или пароль.');
          }
          rethrow;
        }
      });

  Future<void> register({
    required String email,
    required String password,
    required String name,
  }) =>
      guard(() async {
        await _dio.post<dynamic>('/collections/users/records',
            data: {
              'email': email,
              'password': password,
              'passwordConfirm': password,
              'name': name,
              'role': 'cadet',
            },
            options: _public);
      });

  Future<AuthResult> refresh() => guard(() async {
        final response =
            await _dio.post<dynamic>('/collections/users/auth-refresh');
        return _result(response.data);
      });

  Future<String?> profileId(AppUser user) => guard(() async {
        final collection = switch (user.role) {
          Role.cadet => 'cadets',
          Role.instructor => 'instructors',
          Role.admin => null,
        };
        if (collection == null) return null;
        final response = await _dio
            .get<dynamic>('/collections/$collection/records', queryParameters: {
          'filter': "user='${user.id}' && deleted=false",
          'perPage': 1,
          'fields': 'id',
        });
        final data = response.data;
        final items = data is Map ? data['items'] : null;
        if (items is List && items.isNotEmpty && items.first is Map) {
          return '${(items.first as Map)['id']}';
        }
        return null;
      });
}
