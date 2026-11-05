/// Satu titik GPS dari hasil rekaman (Strava-like).
/// `t` = epoch millis, `e` = elevasi meter (bisa 0 bila GPS tak memberi alt).
class GpsPoint {
  final double lat;
  final double lng;
  final double ele;
  final int t;
  const GpsPoint({
    required this.lat,
    required this.lng,
    this.ele = 0,
    required this.t,
  });

  Map<String, Object?> toJson() => {'lat': lat, 'lng': lng, 'ele': ele, 't': t};

  static GpsPoint? fromJson(Object? o) {
    if (o is! Map) return null;
    final lat = (o['lat'] as num?)?.toDouble();
    final lng = (o['lng'] as num?)?.toDouble();
    if (lat == null || lng == null) return null;
    if (lat < -90 || lat > 90 || lng < -180 || lng > 180) return null;
    return GpsPoint(
      lat: lat,
      lng: lng,
      ele: ((o['ele'] as num?)?.toDouble() ?? 0).clamp(-500, 9000),
      t: (o['t'] as num?)?.toInt() ?? 0,
    );
  }
}

class CyclingActivity {
  final int id;
  final String name;
  final double distance; // meter
  final double totalElevationGain; // meter
  final double averageSpeed; // m/s
  final String startDate; // ISO yyyy-MM-ddTHH:mm:ssZ
  final double averageHeartRate; // bpm, 0 = no data
  final String note;

  /// Rute GPS tersimpan sebagai JSON ringkas: [[lat,lng,ele,t], ...].
  /// '' = sesi manual / impor CSV tanpa rute.
  final String routeJson;

  /// Durasi real hasil rekaman GPS (detik). 0 = hitung dari jarak/kecepatan.
  final double durationSec;

  /// Penanda ringan "sesi punya rute GPS".
  ///
  /// Query daftar (riwayat) sengaja TIDAK memuat [routeJson] agar memori
  /// tetap kecil walau riwayat panjang; nilai ini diisi dari SQL. Untuk
  /// objek yang dimuat penuh, nilainya sama dengan `routeJson.isNotEmpty`.
  final bool hasRouteData;

  const CyclingActivity({
    this.id = 0,
    required this.name,
    required this.distance,
    required this.totalElevationGain,
    required this.averageSpeed,
    required this.startDate,
    this.averageHeartRate = 0,
    this.note = '',
    this.routeJson = '',
    this.durationSec = 0,
    this.hasRouteData = false,
  });

  double get distanceKm => distance / 1000.0;
  double get speedKmh => averageSpeed * 3.6;
  String get dateKey =>
      startDate.length >= 10 ? startDate.substring(0, 10) : startDate;

  /// Durasi GPS diutamakan bila ada; fallback ke jarak/kecepatan (sesi manual).
  double get durationMin => durationSec > 0
      ? durationSec / 60.0
      : (averageSpeed > 0 ? distance / averageSpeed / 60.0 : 0);
  bool get hasRoute => hasRouteData || routeJson.isNotEmpty;

  CyclingActivity copyWith({
    int? id,
    String? name,
    double? distance,
    double? totalElevationGain,
    double? averageSpeed,
    String? startDate,
    double? averageHeartRate,
    String? note,
    String? routeJson,
    double? durationSec,
    bool? hasRouteData,
  }) {
    return CyclingActivity(
      id: id ?? this.id,
      name: name ?? this.name,
      distance: distance ?? this.distance,
      totalElevationGain: totalElevationGain ?? this.totalElevationGain,
      averageSpeed: averageSpeed ?? this.averageSpeed,
      startDate: startDate ?? this.startDate,
      averageHeartRate: averageHeartRate ?? this.averageHeartRate,
      note: note ?? this.note,
      routeJson: routeJson ?? this.routeJson,
      durationSec: durationSec ?? this.durationSec,
      hasRouteData: hasRouteData ?? this.hasRouteData,
    );
  }
}

class EventGoal {
  final int id;
  final String name;
  final String eventDate; // yyyy-MM-dd
  final double targetDistanceKm;
  final double targetElevationM;
  final int createdAt;

  /// Rute resmi panitia dari file GPX (JSON ringkas [[lat,lng,ele,t], ...]).
  /// '' = event belum punya rute GPX.
  final String routeJson;

  const EventGoal({
    this.id = 0,
    required this.name,
    required this.eventDate,
    required this.targetDistanceKm,
    this.targetElevationM = 0,
    required this.createdAt,
    this.routeJson = '',
  });

  bool get hasRoute => routeJson.isNotEmpty;

  EventGoal copyWith({
    int? id,
    String? name,
    String? eventDate,
    double? targetDistanceKm,
    double? targetElevationM,
    int? createdAt,
    String? routeJson,
  }) {
    return EventGoal(
      id: id ?? this.id,
      name: name ?? this.name,
      eventDate: eventDate ?? this.eventDate,
      targetDistanceKm: targetDistanceKm ?? this.targetDistanceKm,
      targetElevationM: targetElevationM ?? this.targetElevationM,
      createdAt: createdAt ?? this.createdAt,
      routeJson: routeJson ?? this.routeJson,
    );
  }
}

double msToKmh(double ms) => ms * 3.6;
double kmhToMs(double kmh) => kmh / 3.6;
String formatDateShort(String iso) =>
    iso.length >= 10 ? iso.substring(0, 10) : iso;
