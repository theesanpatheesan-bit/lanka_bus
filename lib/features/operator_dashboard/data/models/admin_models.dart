import 'package:equatable/equatable.dart';

class AdminMetrics extends Equatable {
  const AdminMetrics({
    required this.bookingsToday,
    required this.revenueTodayLkr,
    required this.activeBuses,
    required this.commissionTodayLkr,
    this.pendingOperators = 0,
    this.activeOperators = 0,
  });

  final int bookingsToday;
  final double revenueTodayLkr;
  final int activeBuses;
  final double commissionTodayLkr;
  final int pendingOperators;
  final int activeOperators;

  factory AdminMetrics.fromJson(Map<String, dynamic> json) {
    return AdminMetrics(
      bookingsToday: (json['bookings_today'] as num?)?.toInt() ?? 0,
      revenueTodayLkr: (json['revenue_today_lkr'] as num?)?.toDouble() ?? 0,
      activeBuses: (json['active_buses'] as num?)?.toInt() ?? 0,
      commissionTodayLkr:
          (json['commission_today_lkr'] as num?)?.toDouble() ?? 0,
      pendingOperators: (json['pending_operators'] as num?)?.toInt() ?? 0,
      activeOperators: (json['active_operators'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  List<Object?> get props =>
      [bookingsToday, revenueTodayLkr, activeBuses, commissionTodayLkr];
}

class AdminOperatorItem extends Equatable {
  const AdminOperatorItem({
    required this.id,
    required this.companyName,
    required this.status,
    required this.createdAt,
    this.tradeName,
    this.brNumber,
    this.vatNumber,
    this.contactEmail,
    this.contactPhone,
    this.addressLine1,
    this.city,
    this.commissionRate,
    this.rating,
    this.ownerName,
    this.ownerEmail,
  });

  final String id;
  final String companyName;
  final String? tradeName;
  final String? brNumber;
  final String? vatNumber;
  final String? contactEmail;
  final String? contactPhone;
  final String? addressLine1;
  final String? city;
  final String status;
  final double? commissionRate;
  final double? rating;
  final DateTime createdAt;
  final String? ownerName;
  final String? ownerEmail;

  factory AdminOperatorItem.fromJson(Map<String, dynamic> json) {
    return AdminOperatorItem(
      id: json['id'] as String,
      companyName: json['company_name'] as String? ?? '',
      tradeName: json['trade_name'] as String?,
      brNumber: json['br_number'] as String?,
      vatNumber: json['vat_number'] as String?,
      contactEmail: json['contact_email'] as String?,
      contactPhone: json['contact_phone'] as String?,
      addressLine1: json['address_line1'] as String?,
      city: json['city'] as String?,
      status: json['status'] as String? ?? 'pending',
      commissionRate: (json['commission_rate'] as num?)?.toDouble(),
      rating: (json['rating'] as num?)?.toDouble(),
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      ownerName: json['owner_name'] as String?,
      ownerEmail: json['owner_email'] as String?,
    );
  }

  @override
  List<Object?> get props => [id, status];
}

class AdminBusItem extends Equatable {
  const AdminBusItem({
    required this.id,
    required this.operatorId,
    required this.busNumber,
    required this.registrationNo,
    required this.busType,
    required this.totalSeats,
    required this.isActive,
    this.operatorName,
    this.amenities = const [],
    this.layoutSeatCount = 0,
  });

  final String id;
  final String operatorId;
  final String? operatorName;
  final String busNumber;
  final String registrationNo;
  final String busType;
  final int totalSeats;
  final List<String> amenities;
  final bool isActive;
  final int layoutSeatCount;

  factory AdminBusItem.fromJson(Map<String, dynamic> json) {
    final amenitiesRaw = json['amenities'];
    final amenities = amenitiesRaw is List
        ? amenitiesRaw.map((e) => e.toString()).toList()
        : <String>[];
    return AdminBusItem(
      id: json['id'] as String,
      operatorId: json['operator_id'] as String,
      operatorName: json['operator_name'] as String?,
      busNumber: json['bus_number'] as String? ?? '',
      registrationNo: json['registration_no'] as String? ?? '',
      busType: json['bus_type'] as String? ?? 'non_ac',
      totalSeats: (json['total_seats'] as num?)?.toInt() ?? 0,
      amenities: amenities,
      isActive: json['is_active'] as bool? ?? true,
      layoutSeatCount: (json['layout_seat_count'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  List<Object?> get props => [id, busNumber];
}

class AdminRoutePointItem extends Equatable {
  const AdminRoutePointItem({
    required this.id,
    required this.pointType,
    required this.name,
    required this.offsetMinutes,
    this.sortOrder = 0,
  });

  final String id;
  final String pointType;
  final String name;
  final int offsetMinutes;
  final int sortOrder;

  factory AdminRoutePointItem.fromJson(Map<String, dynamic> json) {
    return AdminRoutePointItem(
      id: json['id'] as String? ?? '',
      pointType: json['point_type'] as String? ?? 'boarding',
      name: json['name'] as String? ?? '',
      offsetMinutes: (json['offset_minutes'] as num?)?.toInt() ?? 0,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  List<Object?> get props => [id, name];
}

class AdminRouteItem extends Equatable {
  const AdminRouteItem({
    required this.id,
    required this.originCity,
    required this.destinationCity,
    required this.isActive,
    this.originTerminal,
    this.destinationTerminal,
    this.distanceKm,
    this.estimatedDurationMinutes,
    this.points = const [],
  });

  final String id;
  final String originCity;
  final String destinationCity;
  final String? originTerminal;
  final String? destinationTerminal;
  final double? distanceKm;
  final int? estimatedDurationMinutes;
  final bool isActive;
  final List<AdminRoutePointItem> points;

  String get label => '$originCity → $destinationCity';

  factory AdminRouteItem.fromJson(Map<String, dynamic> json) {
    final pointsRaw = json['points'];
    final points = pointsRaw is List
        ? pointsRaw
            .map((e) =>
                AdminRoutePointItem.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList()
        : <AdminRoutePointItem>[];
    return AdminRouteItem(
      id: json['id'] as String,
      originCity: json['origin_city'] as String? ?? '',
      destinationCity: json['destination_city'] as String? ?? '',
      originTerminal: json['origin_terminal'] as String?,
      destinationTerminal: json['destination_terminal'] as String?,
      distanceKm: (json['distance_km'] as num?)?.toDouble(),
      estimatedDurationMinutes:
          (json['estimated_duration_minutes'] as num?)?.toInt(),
      isActive: json['is_active'] as bool? ?? true,
      points: points,
    );
  }

  @override
  List<Object?> get props => [id, label];
}
