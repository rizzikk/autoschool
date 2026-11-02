import '../models/pb_record.dart';
import '../util/format.dart';
import 'progress.dart';

class ReportData {
  const ReportData({
    required this.from,
    required this.to,
    required this.lessonsByStatus,
    required this.drivingMinutes,
    required this.hoursByInstructor,
    required this.revenueByMonth,
    required this.revenueTotal,
    required this.cadetsByStatus,
    required this.examsPassed,
    required this.examsTotal,
  });

  final DateTime from;
  final DateTime to;

  final Map<String, int> lessonsByStatus;

  final int drivingMinutes;

  final Map<String, int> hoursByInstructor;

  final Map<String, int> revenueByMonth;
  final int revenueTotal;
  final Map<String, int> cadetsByStatus;
  final int examsPassed;
  final int examsTotal;

  int get lessonsTotal => lessonsByStatus.values.fold(0, (a, b) => a + b);

  double get passRate => examsTotal == 0 ? 0 : examsPassed / examsTotal;
}

String monthKey(DateTime d) => '${d.year}-${two(d.month)}';

String monthLabel(String key) {
  final p = key.split('-');
  final m = int.tryParse(p.length > 1 ? p[1] : '') ?? 1;
  return '${monthNames[(m - 1).clamp(0, 11)].substring(0, 3)} ${p.first}';
}

ReportData buildReport({
  required DateTime from,
  required DateTime to,
  required List<PbRecord> lessons,
  required List<PbRecord> payments,
  required List<PbRecord> exams,
  required List<PbRecord> cadets,
}) {
  final byStatus = <String, int>{
    'planned': 0,
    'done': 0,
    'cancelled': 0,
    'no_show': 0,
  };
  final byInstructor = <String, int>{};
  var minutes = 0;
  for (final l in lessons.where((l) => !l.deleted)) {
    final s = l.str('status');
    byStatus[s] = (byStatus[s] ?? 0) + 1;
    if (s == 'done') {
      final m = lessonMinutes(l);
      minutes += m;
      final name = l.one('instructor')?.str('full_name') ?? 'Без инструктора';
      byInstructor[name] = (byInstructor[name] ?? 0) + m;
    }
  }
  final revenue = <String, int>{};
  var total = 0;
  for (final p in payments.where((p) => !p.deleted)) {
    final d = p.date('paid_at');
    if (d == null) continue;
    final amount = p.integer('amount');
    revenue[monthKey(d)] = (revenue[monthKey(d)] ?? 0) + amount;
    total += amount;
  }
  final sortedRevenue = Map.fromEntries(
      revenue.entries.toList()..sort((a, b) => a.key.compareTo(b.key)));
  final cadetStatus = <String, int>{};
  for (final c in cadets.where((c) => !c.deleted)) {
    final s = c.str('status');
    cadetStatus[s] = (cadetStatus[s] ?? 0) + 1;
  }
  final held = exams
      .where((e) =>
          !e.deleted && const ['passed', 'failed'].contains(e.str('result')))
      .toList();
  return ReportData(
    from: from,
    to: to,
    lessonsByStatus: byStatus,
    drivingMinutes: minutes,
    hoursByInstructor: byInstructor,
    revenueByMonth: sortedRevenue,
    revenueTotal: total,
    cadetsByStatus: cadetStatus,
    examsPassed: held.where((e) => e.str('result') == 'passed').length,
    examsTotal: held.length,
  );
}

String buildCsv(List<List<String>> rows) {
  String cell(String v) {
    final needsQuotes = v.contains(';') ||
        v.contains('"') ||
        v.contains('\n') ||
        v.contains('\r');
    final escaped = v.replaceAll('"', '""');
    return needsQuotes ? '"$escaped"' : escaped;
  }

  return rows.map((r) => r.map(cell).join(';')).join('\r\n');
}
