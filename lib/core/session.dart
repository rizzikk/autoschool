import 'jwt.dart';

class ApiSession {
  String? accessToken;

  Future<bool> Function()? refresh;

  bool isExpiringSoon(Duration margin, {DateTime? now}) {
    final token = accessToken;
    if (token == null) return false;
    final exp = jwtExpiry(token);
    if (exp == null) return false;
    return exp.difference(now ?? DateTime.now()) < margin;
  }
}
