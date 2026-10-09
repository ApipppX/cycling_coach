// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $CyclingActivitiesTable extends CyclingActivities
    with TableInfo<$CyclingActivitiesTable, ActivityRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CyclingActivitiesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _distanceMeta = const VerificationMeta(
    'distance',
  );
  @override
  late final GeneratedColumn<double> distance = GeneratedColumn<double>(
    'distance',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _totalElevationGainMeta =
      const VerificationMeta('totalElevationGain');
  @override
  late final GeneratedColumn<double> totalElevationGain =
      GeneratedColumn<double>(
        'total_elevation_gain',
        aliasedName,
        false,
        type: DriftSqlType.double,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _averageSpeedMeta = const VerificationMeta(
    'averageSpeed',
  );
  @override
  late final GeneratedColumn<double> averageSpeed = GeneratedColumn<double>(
    'average_speed',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startDateMeta = const VerificationMeta(
    'startDate',
  );
  @override
  late final GeneratedColumn<String> startDate = GeneratedColumn<String>(
    'start_date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _averageHeartRateMeta = const VerificationMeta(
    'averageHeartRate',
  );
  @override
  late final GeneratedColumn<double> averageHeartRate = GeneratedColumn<double>(
    'average_heart_rate',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _routeJsonMeta = const VerificationMeta(
    'routeJson',
  );
  @override
  late final GeneratedColumn<String> routeJson = GeneratedColumn<String>(
    'route_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _durationSecMeta = const VerificationMeta(
    'durationSec',
  );
  @override
  late final GeneratedColumn<double> durationSec = GeneratedColumn<double>(
    'duration_sec',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    distance,
    totalElevationGain,
    averageSpeed,
    startDate,
    averageHeartRate,
    note,
    routeJson,
    durationSec,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cycling_activities';
  @override
  VerificationContext validateIntegrity(
    Insertable<ActivityRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('distance')) {
      context.handle(
        _distanceMeta,
        distance.isAcceptableOrUnknown(data['distance']!, _distanceMeta),
      );
    } else if (isInserting) {
      context.missing(_distanceMeta);
    }
    if (data.containsKey('total_elevation_gain')) {
      context.handle(
        _totalElevationGainMeta,
        totalElevationGain.isAcceptableOrUnknown(
          data['total_elevation_gain']!,
          _totalElevationGainMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_totalElevationGainMeta);
    }
    if (data.containsKey('average_speed')) {
      context.handle(
        _averageSpeedMeta,
        averageSpeed.isAcceptableOrUnknown(
          data['average_speed']!,
          _averageSpeedMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_averageSpeedMeta);
    }
    if (data.containsKey('start_date')) {
      context.handle(
        _startDateMeta,
        startDate.isAcceptableOrUnknown(data['start_date']!, _startDateMeta),
      );
    } else if (isInserting) {
      context.missing(_startDateMeta);
    }
    if (data.containsKey('average_heart_rate')) {
      context.handle(
        _averageHeartRateMeta,
        averageHeartRate.isAcceptableOrUnknown(
          data['average_heart_rate']!,
          _averageHeartRateMeta,
        ),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('route_json')) {
      context.handle(
        _routeJsonMeta,
        routeJson.isAcceptableOrUnknown(data['route_json']!, _routeJsonMeta),
      );
    }
    if (data.containsKey('duration_sec')) {
      context.handle(
        _durationSecMeta,
        durationSec.isAcceptableOrUnknown(
          data['duration_sec']!,
          _durationSecMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ActivityRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ActivityRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      distance: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}distance'],
      )!,
      totalElevationGain: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}total_elevation_gain'],
      )!,
      averageSpeed: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}average_speed'],
      )!,
      startDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}start_date'],
      )!,
      averageHeartRate: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}average_heart_rate'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      )!,
      routeJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}route_json'],
      )!,
      durationSec: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}duration_sec'],
      )!,
    );
  }

  @override
  $CyclingActivitiesTable createAlias(String alias) {
    return $CyclingActivitiesTable(attachedDatabase, alias);
  }
}

class ActivityRow extends DataClass implements Insertable<ActivityRow> {
  final int id;
  final String name;
  final double distance;
  final double totalElevationGain;
  final double averageSpeed;
  final String startDate;
  final double averageHeartRate;
  final String note;
  final String routeJson;
  final double durationSec;
  const ActivityRow({
    required this.id,
    required this.name,
    required this.distance,
    required this.totalElevationGain,
    required this.averageSpeed,
    required this.startDate,
    required this.averageHeartRate,
    required this.note,
    required this.routeJson,
    required this.durationSec,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['distance'] = Variable<double>(distance);
    map['total_elevation_gain'] = Variable<double>(totalElevationGain);
    map['average_speed'] = Variable<double>(averageSpeed);
    map['start_date'] = Variable<String>(startDate);
    map['average_heart_rate'] = Variable<double>(averageHeartRate);
    map['note'] = Variable<String>(note);
    map['route_json'] = Variable<String>(routeJson);
    map['duration_sec'] = Variable<double>(durationSec);
    return map;
  }

  CyclingActivitiesCompanion toCompanion(bool nullToAbsent) {
    return CyclingActivitiesCompanion(
      id: Value(id),
      name: Value(name),
      distance: Value(distance),
      totalElevationGain: Value(totalElevationGain),
      averageSpeed: Value(averageSpeed),
      startDate: Value(startDate),
      averageHeartRate: Value(averageHeartRate),
      note: Value(note),
      routeJson: Value(routeJson),
      durationSec: Value(durationSec),
    );
  }

  factory ActivityRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ActivityRow(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      distance: serializer.fromJson<double>(json['distance']),
      totalElevationGain: serializer.fromJson<double>(
        json['totalElevationGain'],
      ),
      averageSpeed: serializer.fromJson<double>(json['averageSpeed']),
      startDate: serializer.fromJson<String>(json['startDate']),
      averageHeartRate: serializer.fromJson<double>(json['averageHeartRate']),
      note: serializer.fromJson<String>(json['note']),
      routeJson: serializer.fromJson<String>(json['routeJson']),
      durationSec: serializer.fromJson<double>(json['durationSec']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'distance': serializer.toJson<double>(distance),
      'totalElevationGain': serializer.toJson<double>(totalElevationGain),
      'averageSpeed': serializer.toJson<double>(averageSpeed),
      'startDate': serializer.toJson<String>(startDate),
      'averageHeartRate': serializer.toJson<double>(averageHeartRate),
      'note': serializer.toJson<String>(note),
      'routeJson': serializer.toJson<String>(routeJson),
      'durationSec': serializer.toJson<double>(durationSec),
    };
  }

  ActivityRow copyWith({
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
  }) => ActivityRow(
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
  );
  ActivityRow copyWithCompanion(CyclingActivitiesCompanion data) {
    return ActivityRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      distance: data.distance.present ? data.distance.value : this.distance,
      totalElevationGain: data.totalElevationGain.present
          ? data.totalElevationGain.value
          : this.totalElevationGain,
      averageSpeed: data.averageSpeed.present
          ? data.averageSpeed.value
          : this.averageSpeed,
      startDate: data.startDate.present ? data.startDate.value : this.startDate,
      averageHeartRate: data.averageHeartRate.present
          ? data.averageHeartRate.value
          : this.averageHeartRate,
      note: data.note.present ? data.note.value : this.note,
      routeJson: data.routeJson.present ? data.routeJson.value : this.routeJson,
      durationSec: data.durationSec.present
          ? data.durationSec.value
          : this.durationSec,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ActivityRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('distance: $distance, ')
          ..write('totalElevationGain: $totalElevationGain, ')
          ..write('averageSpeed: $averageSpeed, ')
          ..write('startDate: $startDate, ')
          ..write('averageHeartRate: $averageHeartRate, ')
          ..write('note: $note, ')
          ..write('routeJson: $routeJson, ')
          ..write('durationSec: $durationSec')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    distance,
    totalElevationGain,
    averageSpeed,
    startDate,
    averageHeartRate,
    note,
    routeJson,
    durationSec,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ActivityRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.distance == this.distance &&
          other.totalElevationGain == this.totalElevationGain &&
          other.averageSpeed == this.averageSpeed &&
          other.startDate == this.startDate &&
          other.averageHeartRate == this.averageHeartRate &&
          other.note == this.note &&
          other.routeJson == this.routeJson &&
          other.durationSec == this.durationSec);
}

class CyclingActivitiesCompanion extends UpdateCompanion<ActivityRow> {
  final Value<int> id;
  final Value<String> name;
  final Value<double> distance;
  final Value<double> totalElevationGain;
  final Value<double> averageSpeed;
  final Value<String> startDate;
  final Value<double> averageHeartRate;
  final Value<String> note;
  final Value<String> routeJson;
  final Value<double> durationSec;
  const CyclingActivitiesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.distance = const Value.absent(),
    this.totalElevationGain = const Value.absent(),
    this.averageSpeed = const Value.absent(),
    this.startDate = const Value.absent(),
    this.averageHeartRate = const Value.absent(),
    this.note = const Value.absent(),
    this.routeJson = const Value.absent(),
    this.durationSec = const Value.absent(),
  });
  CyclingActivitiesCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required double distance,
    required double totalElevationGain,
    required double averageSpeed,
    required String startDate,
    this.averageHeartRate = const Value.absent(),
    this.note = const Value.absent(),
    this.routeJson = const Value.absent(),
    this.durationSec = const Value.absent(),
  }) : name = Value(name),
       distance = Value(distance),
       totalElevationGain = Value(totalElevationGain),
       averageSpeed = Value(averageSpeed),
       startDate = Value(startDate);
  static Insertable<ActivityRow> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<double>? distance,
    Expression<double>? totalElevationGain,
    Expression<double>? averageSpeed,
    Expression<String>? startDate,
    Expression<double>? averageHeartRate,
    Expression<String>? note,
    Expression<String>? routeJson,
    Expression<double>? durationSec,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (distance != null) 'distance': distance,
      if (totalElevationGain != null)
        'total_elevation_gain': totalElevationGain,
      if (averageSpeed != null) 'average_speed': averageSpeed,
      if (startDate != null) 'start_date': startDate,
      if (averageHeartRate != null) 'average_heart_rate': averageHeartRate,
      if (note != null) 'note': note,
      if (routeJson != null) 'route_json': routeJson,
      if (durationSec != null) 'duration_sec': durationSec,
    });
  }

  CyclingActivitiesCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<double>? distance,
    Value<double>? totalElevationGain,
    Value<double>? averageSpeed,
    Value<String>? startDate,
    Value<double>? averageHeartRate,
    Value<String>? note,
    Value<String>? routeJson,
    Value<double>? durationSec,
  }) {
    return CyclingActivitiesCompanion(
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
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (distance.present) {
      map['distance'] = Variable<double>(distance.value);
    }
    if (totalElevationGain.present) {
      map['total_elevation_gain'] = Variable<double>(totalElevationGain.value);
    }
    if (averageSpeed.present) {
      map['average_speed'] = Variable<double>(averageSpeed.value);
    }
    if (startDate.present) {
      map['start_date'] = Variable<String>(startDate.value);
    }
    if (averageHeartRate.present) {
      map['average_heart_rate'] = Variable<double>(averageHeartRate.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (routeJson.present) {
      map['route_json'] = Variable<String>(routeJson.value);
    }
    if (durationSec.present) {
      map['duration_sec'] = Variable<double>(durationSec.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CyclingActivitiesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('distance: $distance, ')
          ..write('totalElevationGain: $totalElevationGain, ')
          ..write('averageSpeed: $averageSpeed, ')
          ..write('startDate: $startDate, ')
          ..write('averageHeartRate: $averageHeartRate, ')
          ..write('note: $note, ')
          ..write('routeJson: $routeJson, ')
          ..write('durationSec: $durationSec')
          ..write(')'))
        .toString();
  }
}

class $EventGoalsTable extends EventGoals
    with TableInfo<$EventGoalsTable, EventRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EventGoalsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _eventDateMeta = const VerificationMeta(
    'eventDate',
  );
  @override
  late final GeneratedColumn<String> eventDate = GeneratedColumn<String>(
    'event_date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _targetDistanceKmMeta = const VerificationMeta(
    'targetDistanceKm',
  );
  @override
  late final GeneratedColumn<double> targetDistanceKm = GeneratedColumn<double>(
    'target_distance_km',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _targetElevationMMeta = const VerificationMeta(
    'targetElevationM',
  );
  @override
  late final GeneratedColumn<double> targetElevationM = GeneratedColumn<double>(
    'target_elevation_m',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    eventDate,
    targetDistanceKm,
    targetElevationM,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'event_goals';
  @override
  VerificationContext validateIntegrity(
    Insertable<EventRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('event_date')) {
      context.handle(
        _eventDateMeta,
        eventDate.isAcceptableOrUnknown(data['event_date']!, _eventDateMeta),
      );
    } else if (isInserting) {
      context.missing(_eventDateMeta);
    }
    if (data.containsKey('target_distance_km')) {
      context.handle(
        _targetDistanceKmMeta,
        targetDistanceKm.isAcceptableOrUnknown(
          data['target_distance_km']!,
          _targetDistanceKmMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_targetDistanceKmMeta);
    }
    if (data.containsKey('target_elevation_m')) {
      context.handle(
        _targetElevationMMeta,
        targetElevationM.isAcceptableOrUnknown(
          data['target_elevation_m']!,
          _targetElevationMMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  EventRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EventRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      eventDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}event_date'],
      )!,
      targetDistanceKm: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}target_distance_km'],
      )!,
      targetElevationM: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}target_elevation_m'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $EventGoalsTable createAlias(String alias) {
    return $EventGoalsTable(attachedDatabase, alias);
  }
}

class EventRow extends DataClass implements Insertable<EventRow> {
  final int id;
  final String name;
  final String eventDate;
  final double targetDistanceKm;
  final double targetElevationM;
  final int createdAt;
  const EventRow({
    required this.id,
    required this.name,
    required this.eventDate,
    required this.targetDistanceKm,
    required this.targetElevationM,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['event_date'] = Variable<String>(eventDate);
    map['target_distance_km'] = Variable<double>(targetDistanceKm);
    map['target_elevation_m'] = Variable<double>(targetElevationM);
    map['created_at'] = Variable<int>(createdAt);
    return map;
  }

  EventGoalsCompanion toCompanion(bool nullToAbsent) {
    return EventGoalsCompanion(
      id: Value(id),
      name: Value(name),
      eventDate: Value(eventDate),
      targetDistanceKm: Value(targetDistanceKm),
      targetElevationM: Value(targetElevationM),
      createdAt: Value(createdAt),
    );
  }

  factory EventRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EventRow(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      eventDate: serializer.fromJson<String>(json['eventDate']),
      targetDistanceKm: serializer.fromJson<double>(json['targetDistanceKm']),
      targetElevationM: serializer.fromJson<double>(json['targetElevationM']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'eventDate': serializer.toJson<String>(eventDate),
      'targetDistanceKm': serializer.toJson<double>(targetDistanceKm),
      'targetElevationM': serializer.toJson<double>(targetElevationM),
      'createdAt': serializer.toJson<int>(createdAt),
    };
  }

  EventRow copyWith({
    int? id,
    String? name,
    String? eventDate,
    double? targetDistanceKm,
    double? targetElevationM,
    int? createdAt,
  }) => EventRow(
    id: id ?? this.id,
    name: name ?? this.name,
    eventDate: eventDate ?? this.eventDate,
    targetDistanceKm: targetDistanceKm ?? this.targetDistanceKm,
    targetElevationM: targetElevationM ?? this.targetElevationM,
    createdAt: createdAt ?? this.createdAt,
  );
  EventRow copyWithCompanion(EventGoalsCompanion data) {
    return EventRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      eventDate: data.eventDate.present ? data.eventDate.value : this.eventDate,
      targetDistanceKm: data.targetDistanceKm.present
          ? data.targetDistanceKm.value
          : this.targetDistanceKm,
      targetElevationM: data.targetElevationM.present
          ? data.targetElevationM.value
          : this.targetElevationM,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EventRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('eventDate: $eventDate, ')
          ..write('targetDistanceKm: $targetDistanceKm, ')
          ..write('targetElevationM: $targetElevationM, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    eventDate,
    targetDistanceKm,
    targetElevationM,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.eventDate == this.eventDate &&
          other.targetDistanceKm == this.targetDistanceKm &&
          other.targetElevationM == this.targetElevationM &&
          other.createdAt == this.createdAt);
}

class EventGoalsCompanion extends UpdateCompanion<EventRow> {
  final Value<int> id;
  final Value<String> name;
  final Value<String> eventDate;
  final Value<double> targetDistanceKm;
  final Value<double> targetElevationM;
  final Value<int> createdAt;
  const EventGoalsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.eventDate = const Value.absent(),
    this.targetDistanceKm = const Value.absent(),
    this.targetElevationM = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  EventGoalsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required String eventDate,
    required double targetDistanceKm,
    this.targetElevationM = const Value.absent(),
    required int createdAt,
  }) : name = Value(name),
       eventDate = Value(eventDate),
       targetDistanceKm = Value(targetDistanceKm),
       createdAt = Value(createdAt);
  static Insertable<EventRow> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? eventDate,
    Expression<double>? targetDistanceKm,
    Expression<double>? targetElevationM,
    Expression<int>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (eventDate != null) 'event_date': eventDate,
      if (targetDistanceKm != null) 'target_distance_km': targetDistanceKm,
      if (targetElevationM != null) 'target_elevation_m': targetElevationM,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  EventGoalsCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String>? eventDate,
    Value<double>? targetDistanceKm,
    Value<double>? targetElevationM,
    Value<int>? createdAt,
  }) {
    return EventGoalsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      eventDate: eventDate ?? this.eventDate,
      targetDistanceKm: targetDistanceKm ?? this.targetDistanceKm,
      targetElevationM: targetElevationM ?? this.targetElevationM,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (eventDate.present) {
      map['event_date'] = Variable<String>(eventDate.value);
    }
    if (targetDistanceKm.present) {
      map['target_distance_km'] = Variable<double>(targetDistanceKm.value);
    }
    if (targetElevationM.present) {
      map['target_elevation_m'] = Variable<double>(targetElevationM.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EventGoalsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('eventDate: $eventDate, ')
          ..write('targetDistanceKm: $targetDistanceKm, ')
          ..write('targetElevationM: $targetElevationM, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $PlanChecksTable extends PlanChecks
    with TableInfo<$PlanChecksTable, PlanCheckRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlanChecksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<String> date = GeneratedColumn<String>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [date];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'plan_checks';
  @override
  VerificationContext validateIntegrity(
    Insertable<PlanCheckRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {date};
  @override
  PlanCheckRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PlanCheckRow(
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}date'],
      )!,
    );
  }

  @override
  $PlanChecksTable createAlias(String alias) {
    return $PlanChecksTable(attachedDatabase, alias);
  }
}

class PlanCheckRow extends DataClass implements Insertable<PlanCheckRow> {
  final String date;
  const PlanCheckRow({required this.date});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['date'] = Variable<String>(date);
    return map;
  }

  PlanChecksCompanion toCompanion(bool nullToAbsent) {
    return PlanChecksCompanion(date: Value(date));
  }

  factory PlanCheckRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PlanCheckRow(date: serializer.fromJson<String>(json['date']));
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{'date': serializer.toJson<String>(date)};
  }

  PlanCheckRow copyWith({String? date}) =>
      PlanCheckRow(date: date ?? this.date);
  PlanCheckRow copyWithCompanion(PlanChecksCompanion data) {
    return PlanCheckRow(date: data.date.present ? data.date.value : this.date);
  }

  @override
  String toString() {
    return (StringBuffer('PlanCheckRow(')
          ..write('date: $date')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => date.hashCode;
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PlanCheckRow && other.date == this.date);
}

class PlanChecksCompanion extends UpdateCompanion<PlanCheckRow> {
  final Value<String> date;
  final Value<int> rowid;
  const PlanChecksCompanion({
    this.date = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PlanChecksCompanion.insert({
    required String date,
    this.rowid = const Value.absent(),
  }) : date = Value(date);
  static Insertable<PlanCheckRow> custom({
    Expression<String>? date,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (date != null) 'date': date,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PlanChecksCompanion copyWith({Value<String>? date, Value<int>? rowid}) {
    return PlanChecksCompanion(
      date: date ?? this.date,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (date.present) {
      map['date'] = Variable<String>(date.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlanChecksCompanion(')
          ..write('date: $date, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $CyclingActivitiesTable cyclingActivities =
      $CyclingActivitiesTable(this);
  late final $EventGoalsTable eventGoals = $EventGoalsTable(this);
  late final $PlanChecksTable planChecks = $PlanChecksTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    cyclingActivities,
    eventGoals,
    planChecks,
  ];
}

typedef $$CyclingActivitiesTableCreateCompanionBuilder =
    CyclingActivitiesCompanion Function({
      Value<int> id,
      required String name,
      required double distance,
      required double totalElevationGain,
      required double averageSpeed,
      required String startDate,
      Value<double> averageHeartRate,
      Value<String> note,
      Value<String> routeJson,
      Value<double> durationSec,
    });
typedef $$CyclingActivitiesTableUpdateCompanionBuilder =
    CyclingActivitiesCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<double> distance,
      Value<double> totalElevationGain,
      Value<double> averageSpeed,
      Value<String> startDate,
      Value<double> averageHeartRate,
      Value<String> note,
      Value<String> routeJson,
      Value<double> durationSec,
    });

class $$CyclingActivitiesTableFilterComposer
    extends Composer<_$AppDatabase, $CyclingActivitiesTable> {
  $$CyclingActivitiesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get distance => $composableBuilder(
    column: $table.distance,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get totalElevationGain => $composableBuilder(
    column: $table.totalElevationGain,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get averageSpeed => $composableBuilder(
    column: $table.averageSpeed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get startDate => $composableBuilder(
    column: $table.startDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get averageHeartRate => $composableBuilder(
    column: $table.averageHeartRate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get routeJson => $composableBuilder(
    column: $table.routeJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get durationSec => $composableBuilder(
    column: $table.durationSec,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CyclingActivitiesTableOrderingComposer
    extends Composer<_$AppDatabase, $CyclingActivitiesTable> {
  $$CyclingActivitiesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get distance => $composableBuilder(
    column: $table.distance,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get totalElevationGain => $composableBuilder(
    column: $table.totalElevationGain,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get averageSpeed => $composableBuilder(
    column: $table.averageSpeed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get startDate => $composableBuilder(
    column: $table.startDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get averageHeartRate => $composableBuilder(
    column: $table.averageHeartRate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get routeJson => $composableBuilder(
    column: $table.routeJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get durationSec => $composableBuilder(
    column: $table.durationSec,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CyclingActivitiesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CyclingActivitiesTable> {
  $$CyclingActivitiesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<double> get distance =>
      $composableBuilder(column: $table.distance, builder: (column) => column);

  GeneratedColumn<double> get totalElevationGain => $composableBuilder(
    column: $table.totalElevationGain,
    builder: (column) => column,
  );

  GeneratedColumn<double> get averageSpeed => $composableBuilder(
    column: $table.averageSpeed,
    builder: (column) => column,
  );

  GeneratedColumn<String> get startDate =>
      $composableBuilder(column: $table.startDate, builder: (column) => column);

  GeneratedColumn<double> get averageHeartRate => $composableBuilder(
    column: $table.averageHeartRate,
    builder: (column) => column,
  );

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<String> get routeJson =>
      $composableBuilder(column: $table.routeJson, builder: (column) => column);

  GeneratedColumn<double> get durationSec => $composableBuilder(
    column: $table.durationSec,
    builder: (column) => column,
  );
}

class $$CyclingActivitiesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CyclingActivitiesTable,
          ActivityRow,
          $$CyclingActivitiesTableFilterComposer,
          $$CyclingActivitiesTableOrderingComposer,
          $$CyclingActivitiesTableAnnotationComposer,
          $$CyclingActivitiesTableCreateCompanionBuilder,
          $$CyclingActivitiesTableUpdateCompanionBuilder,
          (
            ActivityRow,
            BaseReferences<_$AppDatabase, $CyclingActivitiesTable, ActivityRow>,
          ),
          ActivityRow,
          PrefetchHooks Function()
        > {
  $$CyclingActivitiesTableTableManager(
    _$AppDatabase db,
    $CyclingActivitiesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CyclingActivitiesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CyclingActivitiesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CyclingActivitiesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<double> distance = const Value.absent(),
                Value<double> totalElevationGain = const Value.absent(),
                Value<double> averageSpeed = const Value.absent(),
                Value<String> startDate = const Value.absent(),
                Value<double> averageHeartRate = const Value.absent(),
                Value<String> note = const Value.absent(),
                Value<String> routeJson = const Value.absent(),
                Value<double> durationSec = const Value.absent(),
              }) => CyclingActivitiesCompanion(
                id: id,
                name: name,
                distance: distance,
                totalElevationGain: totalElevationGain,
                averageSpeed: averageSpeed,
                startDate: startDate,
                averageHeartRate: averageHeartRate,
                note: note,
                routeJson: routeJson,
                durationSec: durationSec,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                required double distance,
                required double totalElevationGain,
                required double averageSpeed,
                required String startDate,
                Value<double> averageHeartRate = const Value.absent(),
                Value<String> note = const Value.absent(),
                Value<String> routeJson = const Value.absent(),
                Value<double> durationSec = const Value.absent(),
              }) => CyclingActivitiesCompanion.insert(
                id: id,
                name: name,
                distance: distance,
                totalElevationGain: totalElevationGain,
                averageSpeed: averageSpeed,
                startDate: startDate,
                averageHeartRate: averageHeartRate,
                note: note,
                routeJson: routeJson,
                durationSec: durationSec,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CyclingActivitiesTable, ActivityRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $CyclingActivitiesTable,
                    ActivityRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CyclingActivitiesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CyclingActivitiesTable,
      ActivityRow,
      $$CyclingActivitiesTableFilterComposer,
      $$CyclingActivitiesTableOrderingComposer,
      $$CyclingActivitiesTableAnnotationComposer,
      $$CyclingActivitiesTableCreateCompanionBuilder,
      $$CyclingActivitiesTableUpdateCompanionBuilder,
      (
        ActivityRow,
        BaseReferences<_$AppDatabase, $CyclingActivitiesTable, ActivityRow>,
      ),
      ActivityRow,
      PrefetchHooks Function()
    >;
typedef $$EventGoalsTableCreateCompanionBuilder = EventGoalsCompanion Function({
  Value<int> id,
  required String name,
  required String eventDate,
  required double targetDistanceKm,
  Value<double> targetElevationM,
  required int createdAt,
});
typedef $$EventGoalsTableUpdateCompanionBuilder = EventGoalsCompanion Function({
  Value<int> id,
  Value<String> name,
  Value<String> eventDate,
  Value<double> targetDistanceKm,
  Value<double> targetElevationM,
  Value<int> createdAt,
});

class $$EventGoalsTableFilterComposer
    extends Composer<_$AppDatabase, $EventGoalsTable> {
  $$EventGoalsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get eventDate => $composableBuilder(
    column: $table.eventDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get targetDistanceKm => $composableBuilder(
    column: $table.targetDistanceKm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get targetElevationM => $composableBuilder(
    column: $table.targetElevationM,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$EventGoalsTableOrderingComposer
    extends Composer<_$AppDatabase, $EventGoalsTable> {
  $$EventGoalsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get eventDate => $composableBuilder(
    column: $table.eventDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get targetDistanceKm => $composableBuilder(
    column: $table.targetDistanceKm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get targetElevationM => $composableBuilder(
    column: $table.targetElevationM,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$EventGoalsTableAnnotationComposer
    extends Composer<_$AppDatabase, $EventGoalsTable> {
  $$EventGoalsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get eventDate =>
      $composableBuilder(column: $table.eventDate, builder: (column) => column);

  GeneratedColumn<double> get targetDistanceKm => $composableBuilder(
    column: $table.targetDistanceKm,
    builder: (column) => column,
  );

  GeneratedColumn<double> get targetElevationM => $composableBuilder(
    column: $table.targetElevationM,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$EventGoalsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $EventGoalsTable,
          EventRow,
          $$EventGoalsTableFilterComposer,
          $$EventGoalsTableOrderingComposer,
          $$EventGoalsTableAnnotationComposer,
          $$EventGoalsTableCreateCompanionBuilder,
          $$EventGoalsTableUpdateCompanionBuilder,
          (EventRow, BaseReferences<_$AppDatabase, $EventGoalsTable, EventRow>),
          EventRow,
          PrefetchHooks Function()
        > {
  $$EventGoalsTableTableManager(_$AppDatabase db, $EventGoalsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EventGoalsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EventGoalsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EventGoalsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> eventDate = const Value.absent(),
                Value<double> targetDistanceKm = const Value.absent(),
                Value<double> targetElevationM = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
              }) => EventGoalsCompanion(
                id: id,
                name: name,
                eventDate: eventDate,
                targetDistanceKm: targetDistanceKm,
                targetElevationM: targetElevationM,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                required String eventDate,
                required double targetDistanceKm,
                Value<double> targetElevationM = const Value.absent(),
                required int createdAt,
              }) => EventGoalsCompanion.insert(
                id: id,
                name: name,
                eventDate: eventDate,
                targetDistanceKm: targetDistanceKm,
                targetElevationM: targetElevationM,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$EventGoalsTable, EventRow>(table),
                  BaseReferences<_$AppDatabase, $EventGoalsTable, EventRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$EventGoalsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $EventGoalsTable,
      EventRow,
      $$EventGoalsTableFilterComposer,
      $$EventGoalsTableOrderingComposer,
      $$EventGoalsTableAnnotationComposer,
      $$EventGoalsTableCreateCompanionBuilder,
      $$EventGoalsTableUpdateCompanionBuilder,
      (EventRow, BaseReferences<_$AppDatabase, $EventGoalsTable, EventRow>),
      EventRow,
      PrefetchHooks Function()
    >;
typedef $$PlanChecksTableCreateCompanionBuilder = PlanChecksCompanion Function({
  required String date,
  Value<int> rowid,
});
typedef $$PlanChecksTableUpdateCompanionBuilder = PlanChecksCompanion Function({
  Value<String> date,
  Value<int> rowid,
});

class $$PlanChecksTableFilterComposer
    extends Composer<_$AppDatabase, $PlanChecksTable> {
  $$PlanChecksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PlanChecksTableOrderingComposer
    extends Composer<_$AppDatabase, $PlanChecksTable> {
  $$PlanChecksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PlanChecksTableAnnotationComposer
    extends Composer<_$AppDatabase, $PlanChecksTable> {
  $$PlanChecksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);
}

class $$PlanChecksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PlanChecksTable,
          PlanCheckRow,
          $$PlanChecksTableFilterComposer,
          $$PlanChecksTableOrderingComposer,
          $$PlanChecksTableAnnotationComposer,
          $$PlanChecksTableCreateCompanionBuilder,
          $$PlanChecksTableUpdateCompanionBuilder,
          (
            PlanCheckRow,
            BaseReferences<_$AppDatabase, $PlanChecksTable, PlanCheckRow>,
          ),
          PlanCheckRow,
          PrefetchHooks Function()
        > {
  $$PlanChecksTableTableManager(_$AppDatabase db, $PlanChecksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlanChecksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PlanChecksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PlanChecksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> date = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => PlanChecksCompanion(date: date, rowid: rowid),
          createCompanionCallback: ({
            required String date,
            Value<int> rowid = const Value.absent(),
          }) => PlanChecksCompanion.insert(date: date, rowid: rowid),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PlanChecksTable, PlanCheckRow>(table),
                  BaseReferences<_$AppDatabase, $PlanChecksTable, PlanCheckRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PlanChecksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PlanChecksTable,
      PlanCheckRow,
      $$PlanChecksTableFilterComposer,
      $$PlanChecksTableOrderingComposer,
      $$PlanChecksTableAnnotationComposer,
      $$PlanChecksTableCreateCompanionBuilder,
      $$PlanChecksTableUpdateCompanionBuilder,
      (
        PlanCheckRow,
        BaseReferences<_$AppDatabase, $PlanChecksTable, PlanCheckRow>,
      ),
      PlanCheckRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$CyclingActivitiesTableTableManager get cyclingActivities =>
      $$CyclingActivitiesTableTableManager(_db, _db.cyclingActivities);
  $$EventGoalsTableTableManager get eventGoals =>
      $$EventGoalsTableTableManager(_db, _db.eventGoals);
  $$PlanChecksTableTableManager get planChecks =>
      $$PlanChecksTableTableManager(_db, _db.planChecks);
}
