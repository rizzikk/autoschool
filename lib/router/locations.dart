import '../models/list_query.dart';

const homePath = '/';
const loginPath = '/login';
const registerPath = '/register';
const forbiddenPath = '/forbidden';
const completeProfilePath = '/complete-profile';
const schedulePath = '/schedule';
const bookPath = '/book';
const progressPath = '/progress';
const reportPath = '/report';

String _location(String path, Map<String, String> params) =>
    Uri(path: path, queryParameters: params.isEmpty ? null : params).toString();

String listLocation(String basePath, ListQuery query) =>
    _location(basePath, query.toParams());

String newLocation(String basePath) => '$basePath/new';
String editLocation(String basePath, String id) => '$basePath/$id/edit';
String detailsLocation(String basePath, String id) => '$basePath/$id';
String progressLocation(String cadetId) => '$progressPath/$cadetId';
