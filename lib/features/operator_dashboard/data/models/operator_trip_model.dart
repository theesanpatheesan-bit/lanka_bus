import 'package:equatable/equatable.dart';

class OperatorTripModel extends Equatable {
  const OperatorTripModel({
    required this.scheduleId,
    required this.busId,
    required this.operatorId,
    required this.departureAt,
    required this.arrivalAt,
    required this.status,
    required this.originCity,
    required this.destinationCity,
    required this.busNumber,
    required this.busRegistration,
    required this.totalSeats,
    required this.bookedSeats,
    required this.boardedSeats,
    required this.revenueLkr,
    this.basePriceLkr = 0,
  });

  final String scheduleId;
  final String busId;
  final String operatorId;
  final DateTime departureAt;
  final DateTime arrivalAt;
  final String status;
  final String originCity;
  final String destinationCity;
  final String busNumber;
  final String busRegistration;
  final int totalSeats;
  final int bookedSeats;
  final int boardedSeats;
  final double revenueLkr;
  final double basePriceLkr;

  String get routeLabel => '$originCity → $destinationCity';

  double get occupancy =>
      totalSeats == 0 ? 0 : bookedSeats / totalSeats;

  factory OperatorTripModel.fromJson(Map<String, dynamic> json) {
    return OperatorTripModel(
      scheduleId: json['schedule_id'] as String,
      busId: json['bus_id'] as String,
      operatorId: json['operator_id'] as String,
      departureAt: DateTime.parse(json['departure_at'] as String).toLocal(),
      arrivalAt: DateTime.parse(json['arrival_at'] as String).toLocal(),
      status: json['status'] as String? ?? 'scheduled',
      originCity: json['origin_city'] as String,
      destinationCity: json['destination_city'] as String,
      busNumber: json['bus_number'] as String? ?? '',
      busRegistration: json['bus_registration'] as String? ?? '',
      totalSeats: (json['total_seats'] as num?)?.toInt() ?? 0,
      bookedSeats: (json['booked_seats'] as num?)?.toInt() ?? 0,
      boardedSeats: (json['boarded_seats'] as num?)?.toInt() ?? 0,
      revenueLkr: (json['revenue_lkr'] as num?)?.toDouble() ?? 0,
      basePriceLkr: (json['base_price_lkr'] as num?)?.toDouble() ?? 0,
    );
  }

  @override
  List<Object?> get props => [scheduleId, bookedSeats, boardedSeats, status];
}

class ManifestPassengerModel extends Equatable {
  const ManifestPassengerModel({
    required this.bookedSeatId,
    required this.seatNumber,
    required this.status,
    required this.passengerName,
    required this.passengerPhone,
    required this.paymentStatus,
    required this.bookingId,
    required this.pnr,
    required this.boardingPoint,
    required this.droppingPoint,
    required this.fareLkr,
    this.boardedAt,
    this.passengerGender,
    this.seatLayoutId,
  });

  final String bookedSeatId;
  final String seatNumber;
  final String status;
  final String passengerName;
  final String passengerPhone;
  final String paymentStatus;
  final String bookingId;
  final String pnr;
  final String boardingPoint;
  final String droppingPoint;
  final double fareLkr;
  final DateTime? boardedAt;
  final String? passengerGender;
  final String? seatLayoutId;

  bool get isBoarded => status == 'boarded' || boardedAt != null;

  factory ManifestPassengerModel.fromJson(Map<String, dynamic> json) {
    return ManifestPassengerModel(
      bookedSeatId: json['booked_seat_id'] as String,
      seatNumber: json['seat_number'] as String,
      status: json['status'] as String? ?? 'booked',
      passengerName: json['passenger_name'] as String? ?? '',
      passengerPhone: json['passenger_phone'] as String? ?? '',
      paymentStatus: json['payment_status'] as String? ?? '',
      bookingId: json['booking_id'] as String,
      pnr: json['pnr'] as String? ?? '',
      boardingPoint: json['boarding_point'] as String? ?? '',
      droppingPoint: json['dropping_point'] as String? ?? '',
      fareLkr: (json['fare_lkr'] as num?)?.toDouble() ?? 0,
      boardedAt: json['boarded_at'] != null
          ? DateTime.parse(json['boarded_at'] as String).toLocal()
          : null,
      passengerGender: json['passenger_gender'] as String?,
      seatLayoutId: json['seat_layout_id'] as String?,
    );
  }

  ManifestPassengerModel copyWith({
    String? status,
    DateTime? boardedAt,
    bool clearBoardedAt = false,
  }) {
    return ManifestPassengerModel(
      bookedSeatId: bookedSeatId,
      seatNumber: seatNumber,
      status: status ?? this.status,
      passengerName: passengerName,
      passengerPhone: passengerPhone,
      paymentStatus: paymentStatus,
      bookingId: bookingId,
      pnr: pnr,
      boardingPoint: boardingPoint,
      droppingPoint: droppingPoint,
      fareLkr: fareLkr,
      boardedAt: clearBoardedAt ? null : (boardedAt ?? this.boardedAt),
      passengerGender: passengerGender,
      seatLayoutId: seatLayoutId,
    );
  }

  @override
  List<Object?> get props => [bookedSeatId, status, boardedAt];
}

enum TicketScanResultType { valid, alreadyScanned, invalid }

class TicketScanResult extends Equatable {
  const TicketScanResult({
    required this.type,
    required this.message,
    this.bookingId,
    this.pnr,
    this.passengerName,
    this.passengerPhone,
    this.boardingPoint,
    this.boardedAt,
    this.seatNumbers = const [],
  });

  final TicketScanResultType type;
  final String message;
  final String? bookingId;
  final String? pnr;
  final String? passengerName;
  final String? passengerPhone;
  final String? boardingPoint;
  final DateTime? boardedAt;
  final List<String> seatNumbers;

  factory TicketScanResult.fromJson(Map<String, dynamic> json) {
    final result = json['result'] as String? ?? 'invalid';
    final seats = json['seats'];
    final seatNumbers = seats is List
        ? seats
            .map((e) => (e as Map)['seat_number']?.toString() ?? '')
            .where((s) => s.isNotEmpty)
            .toList()
        : <String>[];

    return TicketScanResult(
      type: switch (result) {
        'valid' => TicketScanResultType.valid,
        'already_scanned' => TicketScanResultType.alreadyScanned,
        _ => TicketScanResultType.invalid,
      },
      message: json['message'] as String? ?? result,
      bookingId: json['booking_id'] as String?,
      pnr: json['pnr'] as String?,
      passengerName: json['passenger_name'] as String?,
      passengerPhone: json['passenger_phone'] as String?,
      boardingPoint: json['boarding_point'] as String?,
      boardedAt: json['boarded_at'] != null
          ? DateTime.parse(json['boarded_at'] as String).toLocal()
          : null,
      seatNumbers: seatNumbers,
    );
  }

  @override
  List<Object?> get props => [type, bookingId, pnr, message];
}
