import 'dart:convert';

import 'package:file_picker/file_picker.dart';

import '../models/models.dart';

/// Batas aman ukuran file GPX (20 MB). Rute event panjang biasanya < 2 MB.
const int maxGpxBytes = 20 * 1024 * 1024;

/// Batas jumlah titik agar peta & navigasi tetap ringan di HP.
const int maxGpxPoints = 100000;

/// Rute hasil impor file GPX.
///
/// [points] sudah tervalidasi (koordinat sah) dan berurutan sesuai file.
/// [segmentCount] > 1 berarti file punya beberapa `<trkseg>`; titiknya
/// digabung berurutan agar tetap bisa dinavigasi sebagai satu rute.
class GpxTrack {
  final String name;
  final List<GpsPoint> points;
  final int segmentCount;

  const GpxTrack({
    required this.name,
    required this.points,
    this.segmentCount = 1,
  });

  bool get hasTime => points.any((p) => p.t > 0);
}

/// Error ramah pengguna saat file bukan GPX / tidak punya rute.
class GpxException implements Exception {
  final String message;
  const GpxException(this.message);

  @override
  String toString() => message;
}

/// Buka file picker lalu baca + parse GPX. Null bila user membatalkan.
///
/// Memakai [FileType.any] karena banyak file GPX dari WhatsApp/panitia
/// terdaftar sebagai `application/octet-stream` di Android — filter ekstensi
/// justru menyembunyikan file tersebut. Validasi tetap ketat di parser.
Future<GpxTrack?> pickGpxFile() async {
  final file = await FilePicker.pickFile(
    dialogTitle: 'Pilih file GPX dari panitia',
    type: FileType.any,
  );
  if (file == null) return null;

  final size = await file.length();
  if (size != null && size > maxGpxBytes) {
    throw const GpxException(
      'File GPX terlalu besar (maksimal 20 MB). Minta versi yang lebih ringkas ke panitia.',
    );
  }

  final bytes = await file.readAsBytes();
  if (bytes.isEmpty) {
    throw const GpxException('File GPX kosong / tidak bisa dibaca.');
  }
  final text = utf8.decode(bytes, allowMalformed: true);
  final fallback = file.name
      .replaceFirst(RegExp(r'\.(gpx|xml)$', caseSensitive: false), '')
      .trim();
  return parseGpxText(text, fallbackName: fallback);
}

/// Parse isi teks GPX menjadi [GpxTrack].
///
/// Mendukung:
/// - `<trkpt>` (utama), fallback `<rtept>`, lalu `<wpt>`;
/// - tag ber-namespace (mis. `<gpx:trkpt>`) dan atribut kutip tunggal/ganda;
/// - `<ele>` & `<time>` opsional (banyak GPX panitia hanya berisi koordinat);
/// - `<metadata><name>` / `<trk><name>` untuk nama rute.
///
/// Melempar [GpxException] bila bukan GPX atau titik rute < 2.
GpxTrack parseGpxText(String xml, {String fallbackName = 'Rute GPX'}) {
  var text = xml;
  if (text.startsWith('\uFEFF')) text = text.substring(1);
  text = text.trimLeft();
  if (text.isEmpty) {
    throw const GpxException('File GPX kosong.');
  }
  if (!RegExp(
    r'<(?:(?:[A-Za-z_][\w.-]*):)?gpx\b',
    caseSensitive: false,
  ).hasMatch(text)) {
    throw const GpxException(
      'File ini bukan GPX yang valid (tag <gpx> tidak ditemukan).',
    );
  }

  var points = _parsePointTags(text, 'trkpt');
  if (points.isEmpty) points = _parsePointTags(text, 'rtept');
  if (points.isEmpty) points = _parsePointTags(text, 'wpt');
  if (points.length < 2) {
    throw const GpxException(
      'GPX tidak berisi rute (butuh minimal 2 titik trkpt/rtept).',
    );
  }

  final name = _trackName(text);
  final segments = RegExp(
    r'<(?:(?:[A-Za-z_][\w.-]*):)?trkseg\b',
    caseSensitive: false,
  ).allMatches(text).length;

  return GpxTrack(
    name: (name == null || name.trim().isEmpty)
        ? (fallbackName.trim().isEmpty ? 'Rute GPX' : fallbackName.trim())
        : name.trim(),
    points: points,
    segmentCount: segments < 1 ? 1 : segments,
  );
}

List<GpsPoint> _parsePointTags(String xml, String tag) {
  // Satu pola menangani tag berpasangan DAN self-closing <trkpt ... />.
  final re = RegExp(
    '<(?:[A-Za-z_][\\w.-]*:)?$tag\\b([^>]*?)(?:/>|>([\\s\\S]*?)<\\/(?:[A-Za-z_][\\w.-]*:)?$tag\\s*>)',
    caseSensitive: false,
  );
  final out = <GpsPoint>[];
  for (final match in re.allMatches(xml)) {
    if (out.length >= maxGpxPoints) break;
    final attrs = match.group(1) ?? '';
    final lat = double.tryParse(_attr(attrs, 'lat') ?? '');
    final lng = double.tryParse(_attr(attrs, 'lon') ?? '');
    if (lat == null || lng == null) continue;
    if (!lat.isFinite || !lng.isFinite) continue;
    if (lat < -90 || lat > 90 || lng < -180 || lng > 180) continue;
    // (0,0) hampir selalu data rusak, bukan rute nyata.
    if (lat == 0 && lng == 0) continue;
    // Titik duplikat berurutan tidak menambah bentuk rute.
    if (out.isNotEmpty && out.last.lat == lat && out.last.lng == lng) {
      continue;
    }

    final inner = match.group(2) ?? '';
    final eleText = _tagText(inner, 'ele');
    final ele = (double.tryParse(eleText ?? '') ?? 0.0)
        .clamp(-500.0, 9000.0)
        .toDouble();
    final timeText = _tagText(inner, 'time');
    var t = 0;
    if (timeText != null) {
      t = DateTime.tryParse(timeText)?.millisecondsSinceEpoch ?? 0;
    }
    out.add(GpsPoint(lat: lat, lng: lng, ele: ele, t: t));
  }
  return out;
}

String? _attr(String attrs, String name) {
  final re = RegExp('([A-Za-z_][\\w:.-]*)\\s*=\\s*(?:"([^"]*)"|\'([^\']*)\')');
  for (final m in re.allMatches(attrs)) {
    if ((m.group(1) ?? '').toLowerCase() == name.toLowerCase()) {
      return m.group(2) ?? m.group(3);
    }
  }
  return null;
}

String? _tagText(String xml, String tag) {
  final re = RegExp(
    '<(?:[A-Za-z_][\\w.-]*:)?$tag\\b[^>]*>([\\s\\S]*?)<\\/(?:[A-Za-z_][\\w.-]*:)?$tag\\s*>',
    caseSensitive: false,
  );
  final raw = re.firstMatch(xml)?.group(1);
  if (raw == null) return null;
  return _cleanXmlText(raw);
}

String? _trackName(String xml) {
  for (final tag in const ['trk', 'rte', 'metadata']) {
    final blockRe = RegExp(
      '<(?:[A-Za-z_][\\w.-]*:)?$tag\\b[^>]*>([\\s\\S]*?)<\\/(?:[A-Za-z_][\\w.-]*:)?$tag\\s*>',
      caseSensitive: false,
    );
    for (final m in blockRe.allMatches(xml)) {
      final name = _tagText(m.group(1) ?? '', 'name');
      if (name != null && name.isNotEmpty) return name;
    }
  }
  return null;
}

String _cleanXmlText(String raw) {
  var s = raw.trim();
  s = s.replaceAllMapped(
    RegExp(r'<!\[CDATA\[([\s\S]*?)\]\]>'),
    (m) => m.group(1) ?? '',
  );
  return _unescapeXml(s).trim();
}

String _unescapeXml(String input) {
  var s = input
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&apos;', "'");
  s = s.replaceAllMapped(
    RegExp(r'&#x([0-9a-fA-F]+);'),
    (m) => String.fromCharCode(int.parse(m.group(1)!, radix: 16)),
  );
  s = s.replaceAllMapped(
    RegExp(r'&#(\d+);'),
    (m) => String.fromCharCode(int.parse(m.group(1)!)),
  );
  // Paling akhir agar "&amp;lt;" tidak berubah dua kali menjadi "<".
  return s.replaceAll('&amp;', '&');
}
