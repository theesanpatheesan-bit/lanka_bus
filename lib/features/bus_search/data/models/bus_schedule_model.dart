import 'package:equatable/equatable.dart';
import 'package:lanka_bus/features/bus_search/data/models/route_model.dart';

enum BusType { ac, nonAc, sleeper, semiSleeper, luxury }

extension BusTypeX on BusType {
  String get label => switch (this) {
        BusType.ac => 'AC',
        BusType.nonAc => 'Non-AC',
        BusType.sleeper => 'Sleeper',
        BusType.semiSleeper => 'Semi-Sleeper',
        BusType.luxury => 'Luxury',
      };

  String get badgeLabel => switch (this) {
        BusType.ac => 'AC Seater',
        BusType.nonAc => 'Non-AC Seater',
        BusType.sleeper => 'AC Sleeper',
        BusType.semiSleeper => 'Semi-Sleeper',
        BusType.luxury => 'Luxury AC',
      };

  static BusType fromDb(String? value) {
    return switch (value) {
      'ac' => BusType.ac,
      'sleeper' => BusType.sleeper,
      'semi_sleeper' => BusType.semiSleeper,
      'luxury' => BusType.luxury,
      _ => BusType.nonAc,
    };
  }

  /// Filter chip groups used in the UI.
  static Set<BusType> group(String filterKey) {
    return switch (filterKey) {
      'ac' => {BusType.ac, BusType.luxury},
      'non_ac' => {BusType.nonAc},
      'sleeper' => {BusType.sleeper, BusType.semiSleeper},
      'seater' => {BusType.ac, BusType.nonAc, BusType.luxury},
      _ => {},
    };
  }
}

class BusScheduleModel extends Equatable {
  const BusScheduleModel({
    required this.id,
    required this.departureAt,
    required this.arrivalAt,
    required this.basePriceLkr,
    required this.availableSeats,
    required this.totalSeats,
    required this.seatsLeft,
    required this.busType,
    required this.operatorId,
    required this.operatorName,
    required this.rating,
    required this.route,
    this.busNumber,
    this.amenities = const [],
  });

  final String id;
  final DateTime departureAt;
  final DateTime arrivalAt;
  final double basePriceLkr;
  final int availableSeats;
  final int totalSeats;
  final int seatsLeft;
  final BusType busType;
  final String operatorId;
  final String operatorName;
  final double rating;
  final RouteModel route;
  final String? busNumber;
  final List<String> amenities;

  Duration get duration => arrivalAt.difference(departureAt);

  String get durationLabel {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours <= 0) return '${minutes}m';
    if (minutes == 0) return '${hours}h';
    return '${hours}h ${minutes}m';
  }

  bool get isLowSeats => seatsLeft > 0 && seatsLeft < 5;

  bool get isSoldOut => seatsLeft <= 0;

  factory BusScheduleModel.fromJoinedJson(Map<String, dynamic> json) {
    final routeJson = Map<String, dynamic>.from(json['routes'] as Map);
    final busJson = Map<String, dynamic>.from(json['buses'] as Map);
    final operatorJson = Map<String, dynamic>.from(json['operators'] as Map);

    final totalSeats = (busJson['total_seats'] as num).toInt();
    final booked = (json['booked_count'] as num?)?.toInt();
    final storedAvailable = (json['available_seats'] as num?)?.toInt();

    final seatsLeft = booked != null
        ? (totalSeats - booked).clamp(0, totalSeats)
        : (storedAvailable ?? totalSeats).clamp(0, totalSeats);

    final amenitiesRaw = busJson['amenities'];
    final amenities = amenitiesRaw is List
        ? amenitiesRaw.map((e) => e.toString()).toList()
        : <String>[];

    return BusScheduleModel(
      id: json['id'] as String,
      departureAt: DateTime.parse(json['departure_at'] as String).toLocal(),
      arrivalAt: DateTime.parse(json['arrival_at'] as String).toLocal(),
      basePriceLkr: (json['base_price_lkr'] as num).toDouble(),
      availableSeats: seatsLeft,
      totalSeats: totalSeats,
      seatsLeft: seatsLeft,
      busType: BusTypeX.fromDb(busJson['bus_type'] as String?),
      operatorId: operatorJson['id'] as String,
      operatorName: (operatorJson['trade_name'] as String?)?.isNotEmpty == true
          ? operatorJson['trade_name'] as String
          : operatorJson['company_name'] as String? ?? 'Operator',
      rating: (operatorJson['rating'] as num?)?.toDouble() ?? 4.5,
      route: RouteModel.fromJson(routeJson),
      busNumber: busJson['bus_number'] as String?,
      amenities: amenities,
    );
  }

  @override
  List<Object?> get props => [id, departureAt, seatsLeft, basePriceLkr];
}
