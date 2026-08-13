import 'package:equatable/equatable.dart';

enum PassengerGender { male, female, other }

extension PassengerGenderX on PassengerGender {
  String get label => switch (this) {
        PassengerGender.male => 'Male',
        PassengerGender.female => 'Female',
        PassengerGender.other => 'Other',
      };

  String get dbValue => name;
}

class PassengerModel extends Equatable {
  const PassengerModel({
    required this.seatNumber,
    required this.seatLayoutId,
    required this.fareLkr,
    this.fullName = '',
    this.age,
    this.gender,
  });

  final String seatNumber;
  final String seatLayoutId;
  final double fareLkr;
  final String fullName;
  final int? age;
  final PassengerGender? gender;

  bool get isValid =>
      fullName.trim().length >= 2 &&
      age != null &&
      age! > 0 &&
      age! < 120 &&
      gender != null;

  PassengerModel copyWith({
    String? fullName,
    int? age,
    PassengerGender? gender,
  }) {
    return PassengerModel(
      seatNumber: seatNumber,
      seatLayoutId: seatLayoutId,
      fareLkr: fareLkr,
      fullName: fullName ?? this.fullName,
      age: age ?? this.age,
      gender: gender ?? this.gender,
    );
  }

  Map<String, dynamic> toPayload() => {
        'seat_number': seatNumber,
        'seat_layout_id': seatLayoutId,
        'fare_lkr': fareLkr,
        'full_name': fullName.trim(),
        'age': age,
        'gender': gender?.dbValue,
      };

  @override
  List<Object?> get props =>
      [seatNumber, seatLayoutId, fareLkr, fullName, age, gender];
}

class RoutePointModel extends Equatable {
  const RoutePointModel({
    required this.id,
    required this.routeId,
    required this.pointType,
    required this.name,
    required this.offsetMinutes,
    required this.sortOrder,
  });

  final String id;
  final String routeId;
  final String pointType; // boarding | dropping
  final String name;
  final int offsetMinutes;
  final int sortOrder;

  factory RoutePointModel.fromJson(Map<String, dynamic> json) {
    return RoutePointModel(
      id: json['id'] as String,
      routeId: json['route_id'] as String,
      pointType: json['point_type'] as String,
      name: json['name'] as String,
      offsetMinutes: (json['offset_minutes'] as num?)?.toInt() ?? 0,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  List<Object?> get props => [id, name, pointType, offsetMinutes];
}
