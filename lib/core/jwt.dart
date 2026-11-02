import 'dart:convert';

DateTime? jwtExpiry(String token) {
  final parts = token.split('.');
  if (parts.length != 3) return null;
  try {
    final payload =
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
    final data = jsonDecode(payload);
    if (data is Map && data['exp'] is num) {
      return DateTime.fromMillisecondsSinceEpoch(
          (data['exp'] as num).toInt() * 1000);
    }
  } on FormatException {
    return null;
  }
  return null;
}
