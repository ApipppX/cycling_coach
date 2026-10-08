import 'dart:convert';
import '../models/models.dart';

/// Backup/restore seluruh data app dalam satu file JSON.
/// Format: {"version":1,"exportedAt":ms,"activities":[...],"events":[...],"prefs":{...}}
String exportBackupJson({
  required List<CyclingActivity> activities,
  required List<EventGoal> events,
  required Map<String, Object?> prefs,
}) {
  final map = {
    'version': 1,
    'exportedAt': DateTime.now().millisecondsSinceEpoch,
    'activities': [
      for (final a in activities)
        {
          'name': a.name,
          'distance': a.distance,
          'totalElevationGain': a.totalElevationGain,
          'averageSpeed': a.averageSpeed,
          'startDate': a.startDate,
          'averageHeartRate': a.averageHeartRate,
          'note': a.note,
          'routeJson': a.routeJson,
          'durationSec': a.durationSec,
        },
    ],
    'events': [
      for (final e in events)
        {
          'name': e.name,
          'eventDate': e.eventDate,
          'targetDistanceKm': e.targetDistanceKm,
          'targetElevationM': e.targetElevationM,
          'createdAt': e.createdAt,
        },
    ],
    'prefs': prefs,
  };
  return const JsonEncoder.withIndent('  ').convert(map);
}

({List<CyclingActivity> activities, List<EventGoal> events, Map<String, Object?> prefs, int skipped}) importBackupJson(
    String text) {
  final activities = <CyclingActivity>[];
  final events = <EventGoal>[];
  final prefs = <String, Object?>{};
  var skipped = 0;
  final dateRe = RegExp(r'\d{4}-\d{2}-\d{2}');
  try {
    final decoded = json.decode(text);
    if (decoded is! Map) return (activities: activities, events: events, prefs: prefs, skipped: 1);
    if (decoded['version'] != 1) return (activities: activities, events: events, prefs: prefs, skipped: 1);

    for (final item in (decoded['activities'] as List? ?? [])) {
      try {
        if (item is! Map) {
          skipped++;
          continue;
        }
        final name = (item['name'] ?? '').toString();
        final date = (item['startDate'] ?? '').toString();
        final dist = (item['distance'] as num?)?.toDouble();
        final speed = (item['averageSpeed'] as num?)?.toDouble();
        if (name.isEmpty ||
            !dateRe.hasMatch(date) ||
            dist == null || dist <= 0 || dist > 500000 ||
            speed == null || speed <= 0 || speed > 60 / 3.6) {
          skipped++;
          continue;
        }
        activities.add(CyclingActivity(
          name: name,
          distance: dist,
          totalElevationGain: ((item['totalElevationGain'] as num?)?.toDouble() ?? 0).clamp(0, 10000),
          averageSpeed: speed,
          startDate: date,
          averageHeartRate: ((item['averageHeartRate'] as num?)?.toDouble() ?? 0).clamp(0, 220),
          note: (item['note'] ?? '').toString(),
          // Backup lama (v1 tanpa rute) tetap terbaca: default ''/0.
          routeJson: (item['routeJson'] ?? '').toString(),
          durationSec: ((item['durationSec'] as num?)?.toDouble() ?? 0).clamp(0, 86400),
        ));
      } catch (_) {
        skipped++;
      }
    }
    for (final item in (decoded['events'] as List? ?? [])) {
      try {
        if (item is! Map) {
          skipped++;
          continue;
        }
        final name = (item['name'] ?? 'Event').toString();
        final date = (item['eventDate'] ?? '').toString();
        final dist = (item['targetDistanceKm'] as num?)?.toDouble();
        if (!dateRe.hasMatch(date) || dist == null || dist <= 0 || dist > 1000) {
          skipped++;
          continue;
        }
        events.add(EventGoal(
          name: name.isEmpty ? 'Event' : name,
          eventDate: date.substring(0, 10),
          targetDistanceKm: dist,
          targetElevationM: (item['targetElevationM'] as num?)?.toDouble() ?? 0,
          createdAt: (item['createdAt'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
        ));
      } catch (_) {
        skipped++;
      }
    }
    final p = decoded['prefs'];
    if (p is Map) {
      for (final k in ['weekly_target_km', 'max_hr', 'user_name', 'user_age', 'weight_kg', 'theme_mode']) {
        if (p.containsKey(k)) prefs[k] = p[k];
      }
    }
  } catch (_) {
    skipped++;
  }
  return (activities: activities, events: events, prefs: prefs, skipped: skipped);
}
