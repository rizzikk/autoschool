import 'permissions.dart';

class AppUser {
  final String id;
  final String email;
  final String name;
  final Role role;

  final String? profileId;

  const AppUser({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    this.profileId,
  });

  String get displayName => name.trim().isEmpty ? email : name;

  factory AppUser.fromRecord(Map<String, dynamic> json, {String? profileId}) =>
      AppUser(
        id: '${json['id'] ?? ''}',
        email: '${json['email'] ?? ''}',
        name: '${json['name'] ?? ''}',
        role: Role.parse(json['role']),
        profileId: profileId,
      );

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: '${json['id'] ?? ''}',
        email: '${json['email'] ?? ''}',
        name: '${json['name'] ?? ''}',
        role: Role.parse(json['role']),
        profileId: json['profileId'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'name': name,
        'role': role.name,
        'profileId': profileId,
      };

  AppUser withProfile(String? profileId) => AppUser(
        id: id,
        email: email,
        name: name,
        role: role,
        profileId: profileId,
      );
}

class AuthResult {
  final String token;
  final AppUser user;
  const AuthResult({required this.token, required this.user});
}
