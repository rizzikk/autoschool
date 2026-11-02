import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/api_exceptions.dart';
import '../core/config.dart';
import '../core/jwt.dart';
import '../core/session.dart';
import 'app_user.dart';
import 'auth_api.dart';
import 'permissions.dart';

enum LogoutReason { manual, inactivity, sessionLimit, expired }

class AuthNotifier extends ChangeNotifier {
  AuthNotifier(
    this._prefs,
    this._api,
    this._session, {
    this.policy = SessionPolicy.fromEnvironment,
    DateTime Function()? clock,
  }) : _now = clock ?? DateTime.now {
    _session.refresh = refreshTokens;
  }

  static const kToken = 'auth_token';
  static const kUser = 'auth_user';
  static const kStartedAt = 'auth_started_at';
  static const kLastActivity = 'auth_last_activity';

  final SharedPreferences _prefs;
  final AuthApi _api;
  final ApiSession _session;
  final SessionPolicy policy;
  final DateTime Function() _now;

  AppUser? _user;
  DateTime? _startedAt;
  DateTime? _lastSavedActivity;
  Timer? _limitTimer;
  Timer? _refreshTimer;
  Future<bool>? _refreshing;
  LogoutReason? _lastLogout;

  AppUser? get user => _user;
  String? get token => _session.accessToken;
  bool get isAuthenticated => _user != null && _session.accessToken != null;
  Role? get role => _user?.role;
  LogoutReason? get lastLogout => _lastLogout;

  bool get needsCadetProfile =>
      isAuthenticated && role == Role.cadet && _user!.profileId == null;

  String? get logoutMessage => switch (_lastLogout) {
        LogoutReason.inactivity => 'Сессия завершена: не было действий '
            'дольше ${_minutes(policy.idleTimeout)}. Войдите снова.',
        LogoutReason.sessionLimit => 'Сессия завершена: прошло '
            '${_minutes(policy.maxDuration)} с момента входа. '
            'Войдите снова.',
        LogoutReason.expired =>
          'Срок входа истёк, и обновить его не удалось. Войдите снова.',
        _ => null,
      };

  DateTime? get sessionEndsAt => _startedAt?.add(policy.maxDuration);

  bool has(Permission permission) => can(role, permission);

  bool canOn(String collection, EntityOp op) => canEntity(role, collection, op);

  Future<void> restore() async {
    final token = _prefs.getString(kToken);
    final cached = _readUser();
    if (token == null || cached == null) return;

    final now = _now();
    final started = _readTime(kStartedAt) ?? now;
    final last = _readTime(kLastActivity) ?? now;
    if (now.difference(started) >= policy.maxDuration) {
      await logout(reason: LogoutReason.sessionLimit);
      return;
    }
    if (now.difference(last) >= policy.idleTimeout) {
      await logout(reason: LogoutReason.inactivity);
      return;
    }
    final expiry = jwtExpiry(token);
    if (expiry != null && !expiry.isAfter(now)) {
      await logout(reason: LogoutReason.expired);
      return;
    }

    _session.accessToken = token;
    _user = cached;
    _startedAt = started;
    if (_session.isExpiringSoon(tokenRefreshBefore, now: now)) {
      if (!await refreshTokens() && _user == null) return;
    }
    _schedule();
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    final result = await _api.login(email.trim(), password);
    _session.accessToken = result.token;
    String? profile;
    try {
      profile = await _api.profileId(result.user);
    } on ApiException {
      profile = null;
    }
    final now = _now();
    _startedAt = now;
    await _prefs.setInt(kStartedAt, now.millisecondsSinceEpoch);
    await _prefs.setInt(kLastActivity, now.millisecondsSinceEpoch);
    _lastSavedActivity = now;
    _lastLogout = null;
    await _apply(result.token, result.user.withProfile(profile));
    _schedule();
    notifyListeners();
  }

  Future<void> register({
    required String email,
    required String password,
    required String name,
  }) async {
    await _api.register(
        email: email.trim(), password: password, name: name.trim());
    await login(email, password);
  }

  Future<void> reloadProfile() async {
    final user = _user;
    if (user == null) return;
    final profile = await _api.profileId(user);
    _user = user.withProfile(profile);
    await _saveUser();
    notifyListeners();
  }

  Future<void> logout({LogoutReason reason = LogoutReason.manual}) async {
    _user = null;
    _startedAt = null;
    _session.accessToken = null;
    _limitTimer?.cancel();
    _limitTimer = null;
    _refreshTimer?.cancel();
    _refreshTimer = null;
    _lastLogout = reason;
    for (final key in const [kToken, kUser, kStartedAt, kLastActivity]) {
      await _prefs.remove(key);
    }
    notifyListeners();
  }

  Future<bool> refreshTokens() =>
      _refreshing ??= _refresh().whenComplete(() => _refreshing = null);

  Future<bool> _refresh() async {
    if (_session.accessToken == null) return false;
    try {
      final result = await _api.refresh();
      final profile = _user?.profileId;
      _session.accessToken = result.token;
      await _apply(result.token, result.user.withProfile(profile));
      _schedule();
      notifyListeners();
      return true;
    } on NetworkException {
      return false;
    } on ApiException {
      await logout(reason: LogoutReason.expired);
      return false;
    }
  }

  void touch() {
    if (!isAuthenticated) return;
    final now = _now();
    final last = _lastSavedActivity;
    if (last != null && now.difference(last) < const Duration(seconds: 5)) {
      return;
    }
    _lastSavedActivity = now;
    unawaited(_prefs.setInt(kLastActivity, now.millisecondsSinceEpoch));
  }

  Future<void> _apply(String token, AppUser user) async {
    _user = user;
    await _prefs.setString(kToken, token);
    await _saveUser();
  }

  Future<void> _saveUser() async {
    final user = _user;
    if (user == null) return;
    await _prefs.setString(kUser, jsonEncode(user.toJson()));
  }

  AppUser? _readUser() {
    final raw = _prefs.getString(kUser);
    if (raw == null) return null;
    try {
      final data = jsonDecode(raw);
      return data is Map
          ? AppUser.fromJson(Map<String, dynamic>.from(data))
          : null;
    } on FormatException {
      return null;
    }
  }

  DateTime? _readTime(String key) {
    final ms = _prefs.getInt(key);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  void _schedule() {
    _limitTimer?.cancel();
    final ends = sessionEndsAt;
    if (ends != null) {
      var left = ends.difference(_now());
      if (left.isNegative) left = Duration.zero;
      _limitTimer =
          Timer(left, () => logout(reason: LogoutReason.sessionLimit));
    }
    _refreshTimer?.cancel();
    _refreshTimer = null;
    final token = _session.accessToken;
    final expiry = token == null ? null : jwtExpiry(token);
    if (expiry != null) {
      var wait = expiry.difference(_now()) - tokenRefreshBefore;
      if (wait.isNegative) wait = const Duration(seconds: 1);
      _refreshTimer = Timer(wait, () => unawaited(refreshTokens()));
    }
  }

  static String _minutes(Duration d) {
    if (d.inSeconds < 60) return '${d.inSeconds} с';
    final m = d.inMinutes;
    final word = m % 10 == 1 && m % 100 != 11 ? 'минуты' : 'минут';
    return '$m $word';
  }

  @override
  void dispose() {
    _limitTimer?.cancel();
    _refreshTimer?.cancel();
    super.dispose();
  }
}
