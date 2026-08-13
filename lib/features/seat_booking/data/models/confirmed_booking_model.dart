import 'package:equatable/equatable.dart';

class ConfirmedSeatInfo extends Equatable {
  const ConfirmedSeatInfo({
    required this.seatNumber,
    required this.fareLkr,
    this.passengerName,
    this.passengerGender,
  });

  final String seatNumber;
  final double fareLkr;
  final String? passengerName;
  final String? passengerGender;

  factory ConfirmedSeatInfo.fromJson(Map<String, dynamic> json) {
    return ConfirmedSeatInfo(
      seatNumber: json['seat_number'] as String,
      fareLkr: (json['fare_lkr'] as num?)?.toDouble() ?? 0,
      passengerName: json['passenger_name'] as String?,
      passengerGender: json['passenger_gender'] as String?,
    );
  }

  @override
  List<Object?> get props => [seatNumber, fareLkr];
}

/// Full confirmation object returned after successful payment.
class ConfirmedBookingModel extends Equatable {
  const ConfirmedBookingModel({
    required this.bookingId,
    required this.pnr,
    required this.bookingStatus,
    required this.paymentStatus,
    required this.paymentMethod,
    required this.paymentReference,
    required this.totalAmountLkr,
    required this.passengerName,
    required this.passengerPhone,
    required this.originCity,
    required this.destinationCity,
    required this.departureAt,
    required this.arrivalAt,
    required this.operatorName,
    required this.operatorPhone,
    required this.busNumber,
    required this.busRegistration,
    required this.boardingPoint,
    required this.droppingPoint,
    required this.seats,
    this.scheduleId,
    this.busId,
    this.passengerEmail,
    this.boardingOffsetMinutes = 0,
    this.droppingOffsetMinutes = 0,
    this.baseFareLkr = 0,
    this.taxLkr = 0,
    this.discountLkr = 0,
    this.promoCode,
    this.bookedAt,
  });

  final String bookingId;
  final String pnr;
  final String bookingStatus;
  final String paymentStatus;
  final String? paymentMethod;
  final String? paymentReference;
  final double totalAmountLkr;
  final double baseFareLkr;
  final double taxLkr;
  final double discountLkr;
  final String? promoCode;
  final String passengerName;
  final String passengerPhone;
  final String? passengerEmail;
  final String? scheduleId;
  final String? busId;
  final String originCity;
  final String destinationCity;
  final DateTime departureAt;
  final DateTime arrivalAt;
  final String operatorName;
  final String operatorPhone;
  final String busNumber;
  final String busRegistration;
  final String boardingPoint;
  final String droppingPoint;
  final int boardingOffsetMinutes;
  final int droppingOffsetMinutes;
  final List<ConfirmedSeatInfo> seats;
  final DateTime? bookedAt;

  String get routeLabel => '$originCity → $destinationCity';

  String get seatsLabel =>
      seats.map((s) => s.seatNumber).join(', ');

  DateTime get boardingTime =>
      departureAt.add(Duration(minutes: boardingOffsetMinutes));

  DateTime get droppingTime =>
      arrivalAt.add(Duration(minutes: droppingOffsetMinutes));

  String get qrPayload => 'LANKA_BUS|$pnr|$bookingId';

  bool get isConfirmed => bookingStatus == 'confirmed';

  factory ConfirmedBookingModel.fromJson(Map<String, dynamic> json) {
    final seatsRaw = json['seats'];
    final seats = seatsRaw is List
        ? seatsRaw
            .map((e) => ConfirmedSeatInfo.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ))
            .toList()
        : <ConfirmedSeatInfo>[];

    return ConfirmedBookingModel(
      bookingId: json['booking_id'] as String,
      pnr: json['pnr'] as String,
      bookingStatus: json['booking_status'] as String,
      paymentStatus: json['payment_status'] as String,
      paymentMethod: json['payment_method'] as String?,
      paymentReference: json['payment_reference'] as String?,
      totalAmountLkr: (json['total_amount_lkr'] as num).toDouble(),
      baseFareLkr: (json['base_fare_lkr'] as num?)?.toDouble() ?? 0,
      taxLkr: (json['tax_lkr'] as num?)?.toDouble() ?? 0,
      discountLkr: (json['discount_lkr'] as num?)?.toDouble() ?? 0,
      promoCode: json['promo_code'] as String?,
      passengerName: json['passenger_name'] as String? ?? '',
      passengerPhone: json['passenger_phone'] as String? ?? '',
      passengerEmail: json['passenger_email'] as String?,
      scheduleId: json['schedule_id'] as String?,
      busId: json['bus_id'] as String?,
      originCity: json['origin_city'] as String,
      destinationCity: json['destination_city'] as String,
      departureAt: DateTime.parse(json['departure_at'] as String).toLocal(),
      arrivalAt: DateTime.parse(json['arrival_at'] as String).toLocal(),
      operatorName: json['operator_name'] as String? ?? 'Operator',
      operatorPhone: json['operator_phone'] as String? ?? '',
      busNumber: json['bus_number'] as String? ?? '',
      busRegistration: json['bus_registration'] as String? ?? '',
      boardingPoint: json['boarding_point'] as String? ?? '',
      droppingPoint: json['dropping_point'] as String? ?? '',
      boardingOffsetMinutes:
          (json['boarding_offset_minutes'] as num?)?.toInt() ?? 0,
      droppingOffsetMinutes:
          (json['dropping_offset_minutes'] as num?)?.toInt() ?? 0,
      seats: seats,
      bookedAt: json['booked_at'] != null
          ? DateTime.parse(json['booked_at'] as String).toLocal()
          : null,
    );
  }

  @override
  List<Object?> get props => [bookingId, pnr, bookingStatus, paymentStatus];
}
