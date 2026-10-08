class CyclingActivity {
  final int id;
  final String name;
  final double distance; // meter
  final double totalElevationGain; // meter
  final double averageSpeed; // m/s
  final String startDate; // ISO yyyy-MM-ddTHH:mm:ssZ
  final double averageHeartRate; // bpm, 0 = no data
  final String note;

  const CyclingActivity({
    this.id = 0,
    required this.name,
    required this.distance,
    required this.totalElevationGain,
    required this.averageSpeed,
    required this.startDate,
    this.averageHeartRate = 0,
    this.note = '',
  });

  double get distanceKm => distance / 1000.0;
  double get speedKmh => averageSpeed * 3.6;
  String get dateKey => startDate.length >= 10 ? startDate.substring(0, 10) : startDate;
  double get durationMin => averageSpeed > 0 ? distance / averageSpeed / 60.0 : 0;

  CyclingActivity copyWith({
    int? id,
    String? name,
    double? distance,
    double? totalElevationGain,
    double? averageSpeed,
    String? startDate,
    double? averageHeartRate,
    String? note,
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

  const EventGoal({
    this.id = 0,
    required this.name,
    required this.eventDate,
    required this.targetDistanceKm,
    this.targetElevationM = 0,
    required this.createdAt,
  });
}

double msToKmh(double ms) => ms * 3.6;
double kmhToMs(double kmh) => kmh / 3.6;
String formatDateShort(String iso) => iso.length >= 10 ? iso.substring(0, 10) : iso;
