import 'package:equatable/equatable.dart';

class RouteStopPoint extends Equatable {
  const RouteStopPoint({
    required this.id,
    required this.name,
    required this.offsetMinutes,
    this.sortOrder = 0,
  });

  final String id;
  final String name;
  final int offsetMinutes;
  final int sortOrder;

  factory RouteStopPoint.fromJson(Map<String, dynamic> json) {
    return RouteStopPoint(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      offsetMinutes: (json['offset_minutes'] as num?)?.toInt() ?? 0,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  List<Object?> get props => [id, name, offsetMinutes];
}

/// Live trip + GPS snapshot for passenger tracking map.
class LiveTrackingSnapshot extends Equatable {
  const LiveTrackingSnapshot({
    required this.busId,
    required this.busNumber,
    required this.originCity,
    required this.destinationCity,
    this.scheduleId,
    this.status,
    this.departureAt,
    this.arrivalAt,
    this.originTerminal,
    this.destinationTerminal,
    this.busRegistration,
    this.operatorName,
    this.operatorPhone,
    this.conductorPhone,
    this.distanceKm,
    this.estimatedDurationMinutes,
    this.latitude,
    this.longitude,
    this.speedKmh,
    this.headingDegrees,
    this.locationUpdatedAt,
    this.isOnline = false,
    this.boardingPoints = const [],
    this.droppingPoints = const [],
  });

  final String? scheduleId;
  final String busId;
  final String? status;
  final DateTime? departureAt;
  final DateTime? arrivalAt;
  final String originCity;
  final String destinationCity;
  final String? originTerminal;
  final String? destinationTerminal;
  final String busNumber;
  final String? busRegistration;
  final String? operatorName;
  final String? operatorPhone;
  final String? conductorPhone;
  final double? distanceKm;
  final int? estimatedDurationMinutes;
  final double? latitude;
  final double? longitude;
  final double? speedKmh;
  final double? headingDegrees;
  final DateTime? locationUpdatedAt;
  final bool isOnline;
  final List<RouteStopPoint> boardingPoints;
  final List<RouteStopPoint> droppingPoints;

  String get routeLabel => '$originCity → $destinationCity';

  String get contactPhone =>
      (conductorPhone?.isNotEmpty == true)
          ? conductorPhone!
          : (operatorPhone ?? '');

  bool get hasPosition => latitude != null && longitude != null;

  String get connectionLabel {
    if (!hasPosition) return 'Waiting for GPS…';
    if (isOnline) return 'Live';
    final updated = locationUpdatedAt;
    if (updated == null) return 'Bus Offline';
    final mins = DateTime.now().difference(updated).inMinutes;
    if (mins < 1) return 'Bus Offline — Last seen just now';
    if (mins == 1) return 'Bus Offline — Last seen 1 min ago';
    return 'Bus Offline — Last seen $mins mins ago';
  }

  factory LiveTrackingSnapshot.fromJson(Map<String, dynamic> json) {
    List<RouteStopPoint> parsePoints(dynamic raw) {
      if (raw is! List) return [];
      return raw
          .map((e) => RouteStopPoint.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }

    return LiveTrackingSnapshot(
      scheduleId: json['schedule_id'] as String?,
      busId: json['bus_id'] as String,
      status: json['status'] as String?,
      departureAt: json['departure_at'] != null
          ? DateTime.parse(json['departure_at'] as String).toLocal()
          : null,
      arrivalAt: json['arrival_at'] != null
          ? DateTime.parse(json['arrival_at'] as String).toLocal()
          : null,
      originCity: json['origin_city'] as String? ?? '',
      destinationCity: json['destination_city'] as String? ?? '',
      originTerminal: json['origin_terminal'] as String?,
      destinationTerminal: json['destination_terminal'] as String?,
      busNumber: json['bus_number'] as String? ?? '',
      busRegistration: json['bus_registration'] as String?,
      operatorName: json['operator_name'] as String?,
      operatorPhone: json['operator_phone'] as String?,
      conductorPhone: json['conductor_phone'] as String?,
      distanceKm: (json['distance_km'] as num?)?.toDouble(),
      estimatedDurationMinutes:
          (json['estimated_duration_minutes'] as num?)?.toInt(),
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      speedKmh: (json['speed_kmh'] as num?)?.toDouble(),
      headingDegrees: (json['heading_degrees'] as num?)?.toDouble(),
      locationUpdatedAt: json['location_updated_at'] != null
          ? DateTime.parse(json['location_updated_at'] as String).toLocal()
          : null,
      isOnline: json['is_online'] as bool? ?? false,
      boardingPoints: parsePoints(json['boarding_points']),
      droppingPoints: parsePoints(json['dropping_points']),
    );
  }

  LiveTrackingSnapshot copyWithLocation({
    required double latitude,
    required double longitude,
    double? speedKmh,
    double? headingDegrees,
    DateTime? locationUpdatedAt,
    bool? isOnline,
  }) {
    return LiveTrackingSnapshot(
      scheduleId: scheduleId,
      busId: busId,
      status: status,
      departureAt: departureAt,
      arrivalAt: arrivalAt,
      originCity: originCity,
      destinationCity: destinationCity,
      originTerminal: originTerminal,
      destinationTerminal: destinationTerminal,
      busNumber: busNumber,
      busRegistration: busRegistration,
      operatorName: operatorName,
      operatorPhone: operatorPhone,
      conductorPhone: conductorPhone,
      distanceKm: distanceKm,
      estimatedDurationMinutes: estimatedDurationMinutes,
      latitude: latitude,
      longitude: longitude,
      speedKmh: speedKmh ?? this.speedKmh,
      headingDegrees: headingDegrees ?? this.headingDegrees,
      locationUpdatedAt: locationUpdatedAt ?? this.locationUpdatedAt,
      isOnline: isOnline ?? this.isOnline,
      boardingPoints: boardingPoints,
      droppingPoints: droppingPoints,
    );
  }

  @override
  List<Object?> get props => [busId, scheduleId, latitude, longitude, locationUpdatedAt];
}
