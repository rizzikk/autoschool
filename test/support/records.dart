import 'package:autoschool_client/models/pb_record.dart';

PbRecord rec(Map<String, dynamic> data,
        [Map<String, List<PbRecord>> expand = const {}]) =>
    PbRecord({'deleted': false, ...data}, expand);

String utc(int y, int m, int d, [int h = 0, int min = 0]) =>
    '${y.toString().padLeft(4, '0')}-${m.toString().padLeft(2, '0')}-'
    '${d.toString().padLeft(2, '0')} ${h.toString().padLeft(2, '0')}:'
    '${min.toString().padLeft(2, '0')}:00.000Z';
