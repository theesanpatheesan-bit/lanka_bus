import 'package:equatable/equatable.dart';

class RouteModel extends Equatable {
  const RouteModel({
    required this.id,
    required this.originCity,
    required this.destinationCity,
    required this.distanceKm,
    required this.estimatedDurationMinutes,
    this.originTerminal,
    this.destinationTerminal,
  });

  final String id;
  final String originCity;
  final String destinationCity;
  final String? originTerminal;
  final String? destinationTerminal;
  final double distanceKm;
  final int estimatedDurationMinutes;

  factory RouteModel.fromJson(Map<String, dynamic> json) {
    return RouteModel(
      id: json['id'] as String,
      originCity: json['origin_city'] as String,
      destinationCity: json['destination_city'] as String,
      originTerminal: json['origin_terminal'] as String?,
      destinationTerminal: json['destination_terminal'] as String?,
      distanceKm: (json['distance_km'] as num).toDouble(),
      estimatedDurationMinutes: json['estimated_duration_minutes'] as int,
    );
  }

  String get label => '$originCity → $destinationCity';

  @override
  List<Object?> get props => [id, originCity, destinationCity];
}
