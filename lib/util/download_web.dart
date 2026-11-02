import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

bool downloadTextFile(String fileName, String content) {
  final bytes = Uint8List.fromList(utf8.encode('\uFEFF$content'));
  final blob = web.Blob(
    <JSAny>[bytes.toJS].toJS,
    web.BlobPropertyBag(type: 'text/csv;charset=utf-8'),
  );
  final url = web.URL.createObjectURL(blob);
  final link = web.document.createElement('a') as web.HTMLAnchorElement
    ..href = url
    ..download = fileName;
  link.click();
  web.URL.revokeObjectURL(url);
  return true;
}
