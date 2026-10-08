import '../models/models.dart';

String _csvCell(String s) => '"${s.replaceAll('"', '""')}"';

String buildActivitiesCsv(List<CyclingActivity> activities) {
  final sb = StringBuffer('id,nama,tanggal,jarak_km,elevasi_m,kecepatan_kmh,hr_bpm,catatan\n');
  for (final a in activities) {
    sb.writeln('${a.id},${_csvCell(a.name)},${formatDateShort(a.startDate)},'
        '${(a.distance / 1000.0).toStringAsFixed(2)},'
        '${a.totalElevationGain.toInt()},'
        '${msToKmh(a.averageSpeed).toStringAsFixed(1)},'
        '${a.averageHeartRate > 0 ? a.averageHeartRate.toInt().toString() : ''},'
        '${_csvCell(a.note)}');
  }
  return sb.toString();
}

List<String> _splitCsvLine(String line) {
  final out = <String>[];
  final cur = StringBuffer();
  var inQuotes = false;
  var i = 0;
  while (i < line.length) {
    final c = line[i];
    if (c == '"') {
      if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
        cur.write('"');
        i++;
      } else {
        inQuotes = !inQuotes;
      }
    } else if (c == ',' && !inQuotes) {
      out.add(cur.toString());
      cur.clear();
    } else {
      cur.write(c);
    }
    i++;
  }
  out.add(cur.toString());
  return out;
}

({List<CyclingActivity> activities, int skipped}) parseActivitiesCsv(String text) {
  final lines = text.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  if (lines.isEmpty) return (activities: [], skipped: 0);
  final data = lines.first.startsWith('id,') ? lines.sublist(1) : lines;
  final ok = <CyclingActivity>[];
  var skipped = 0;
  final dateRe = RegExp(r'\d{4}-\d{2}-\d{2}');
  for (final line in data) {
    try {
      final cols = _splitCsvLine(line);
      if (cols.length < 7) {
        skipped++;
        continue;
      }
      final name = cols[1].trim();
      final date = cols[2].trim();
      final distKm = double.tryParse(cols[3].trim());
      final elev = double.tryParse(cols[4].trim());
      final speedKmh = double.tryParse(cols[5].trim());
      final hrRaw = cols[6].trim();
      final hr = hrRaw.isEmpty ? 0.0 : double.tryParse(hrRaw);
      // Kompatibilitas: 9 kolom (format lama berisi rpe) atau 8/7 kolom.
      String note = '';
      if (cols.length >= 9) {
        note = cols[8].trim();
      } else if (cols.length == 8) {
        note = cols[7].trim();
      }
      final valid = name.isNotEmpty &&
          dateRe.hasMatch(date) &&
          distKm != null && distKm > 0 && distKm <= 500 &&
          elev != null && elev >= 0 && elev <= 10000 &&
          speedKmh != null && speedKmh > 0 && speedKmh <= 60 &&
          hr != null && hr >= 0 && (hr == 0 || hr >= 40) && hr <= 220;
      if (!valid) {
        skipped++;
        continue;
      }
      ok.add(CyclingActivity(
        name: name,
        distance: distKm * 1000.0,
        totalElevationGain: elev,
        averageSpeed: kmhToMs(speedKmh),
        startDate: '${date}T07:00:00Z',
        averageHeartRate: hr < 40 ? 0 : hr,
        note: note,
      ));
    } catch (_) {
      skipped++;
    }
  }
  return (activities: ok, skipped: skipped);
}
