import 'dart:io';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import '../models/models.dart';
import 'coach_engine.dart';
import 'health_stats.dart';

Future<File> buildWeeklyReportPdf(String profileName,
    List<CyclingActivity> activities, double targetKm, int maxHr,
    [double weightKg = 70, EventGoal? event]) async {
  final a = analyzeCoach(activities, maxHr, event);
  final today = todayString();
  final rec = computeRecords(activities);
  final last7 =
      activities.where((x) => x.dateKey.compareTo(weekStartMonday(0)) >= 0 && x.dateKey.compareTo(today) <= 0).toList()
        ..sort((x, y) => y.dateKey.compareTo(x.dateKey));
  final kcal7 = totalCaloriesKcal(last7, weightKg);
  String topZone = '-';
  double topMin = 0;
  a.hrZoneMinutes.forEach((z, m) {
    if (m > topMin) {
      topMin = m;
      topZone = z;
    }
  });
  final doc = pw.Document();

  pw.Widget h(String t) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 10, bottom: 4),
        child: pw.Text(t,
            style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold, fontSize: 14)),
      );

  pw.Widget kv(String k, String v) => pw.Row(children: [
        pw.Expanded(child: pw.Text(k)),
        pw.Text(v, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
      ]);

  doc.addPage(pw.MultiPage(
    build: (ctx) => [
      pw.Header(
          level: 0,
          text: 'Laporan Mingguan CyclingCoach'),
      pw.Text('Rider: ${profileName.isEmpty ? 'Rider' : profileName} | Target: ${targetKm.toStringAsFixed(0)} km/minggu | MaxHR: $maxHr bpm'),
      if (event != null)
        pw.Text('Event: ${event.name} • ${event.eventDate} • ${event.targetDistanceKm.toStringAsFixed(0)} km (H-${daysUntil(event.eventDate)})'),
      h('Ringkasan 7 Hari'),
      kv('Jarak', '${a.last7Km.toStringAsFixed(1)} km'),
      kv('Sesi', '${last7.length}'),
      kv('Kecepatan rata-rata',
          '${a.avgSpeedKmh.toStringAsFixed(1)} km/h'),
      kv('Estimasi kalori', '${kcal7.toStringAsFixed(0)} kkal'),
      kv('Beban (CTL/ATL/TSB)',
          '${a.ctl.toStringAsFixed(0)} / ${a.atl.toStringAsFixed(0)} / ${a.tsb.toStringAsFixed(0)} (${a.freshnessLabel})'),
      kv('Mix sesi', a.weekMix),
      kv('Sesi acuan', '${a.latestName} (${a.latestDate})'),
      kv('Sesi GPS', '${last7.where((s) => s.hasRoute).length}/${last7.length} dengan peta rute'),
      if (topMin > 0)
        kv('Zona dominan',
            '$topZone (${topMin.toStringAsFixed(0)} mnt)'),
      if (rec != null)
        pw.Text(
            'Rekor: terjauh ${rec.longestKm.toStringAsFixed(1)} km (${rec.longestName}), tercepat ${rec.fastestKmh.toStringAsFixed(1)} km/h, tanjakan ${rec.maxElevM.toInt()} m'),
      h('Zona HR (semua sesi)'),
      pw.TableHelper.fromTextArray(
        headers: ['Zona', 'Rentang', 'Sesi'],
        data: [
          for (final z in ['Z1', 'Z2', 'Z3', 'Z4', 'Z5'])
            [z, hrZoneDesc(z), (a.hrZones[z] ?? 0).toString()],
        ],
      ),
      h('Sesi 7 Hari Terakhir'),
      if (last7.isEmpty)
        pw.Text('Belum ada sesi minggu ini.')
      else
        pw.TableHelper.fromTextArray(
          headers: ['Tanggal', 'Nama', 'Jarak', 'Kec.', 'HR'],
          data: [
            for (final s in last7.take(10))
              [
                formatDateShort(s.startDate),
                s.name.length > 22
                    ? '${s.name.substring(0, 22)}..'
                    : s.name,
                '${s.distanceKm.toStringAsFixed(1)} km',
                s.speedKmh.toStringAsFixed(1),
                s.averageHeartRate > 0
                    ? '${s.averageHeartRate.toInt()}'
                    : '-',
              ],
          ],
        ),
      h('Rekomendasi Coach'),
      pw.Text(a.todayTitle,
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
      pw.Text(a.todayDetail),
      pw.Text('Alasan: ${a.recoveryReason}'),
      pw.Text('Plan minggu: ${a.weekPlan}'),
      if (a.warnings.isNotEmpty) h('Peringatan'),
      for (final w in a.warnings) pw.Bullet(text: w),
    ],
  ));
  final dir = await getTemporaryDirectory();
  final f = File('${dir.path}/laporan_mingguan_cyclingcoach.pdf');
  await f.writeAsBytes(await doc.save());
  return f;
}
