import 'package:equatable/equatable.dart';
import 'package:lanka_bus/features/seat_booking/data/models/passenger_model.dart';
import 'package:lanka_bus/features/seat_booking/data/models/seat_model.dart';

class BookingSummaryModel extends Equatable {
  const BookingSummaryModel({
    required this.scheduleId,
    required this.bookingId,
    required this.operatorName,
    required this.routeLabel,
    required this.departureAt,
    required this.selectedSeats,
    required this.passengers,
    required this.contactEmail,
    required this.contactPhone,
    required this.boardingPoint,
    required this.droppingPoint,
    required this.baseFareLkr,
    required this.taxLkr,
    required this.discountLkr,
    required this.totalLkr,
    this.promoCode,
  });

  final String scheduleId;
  final String bookingId;
  final String operatorName;
  final String routeLabel;
  final DateTime departureAt;
  final List<SeatModel> selectedSeats;
  final List<PassengerModel> passengers;
  final String contactEmail;
  final String contactPhone;
  final RoutePointModel boardingPoint;
  final RoutePointModel droppingPoint;
  final double baseFareLkr;
  final double taxLkr;
  final double discountLkr;
  final double totalLkr;
  final String? promoCode;

  static const taxRate = 0.05;
  static const promoCodeValue = 'SRILANKA20';
  static const promoDiscountRate = 0.10;

  static ({double base, double tax, double discount, double total}) calculate({
    required List<SeatModel> seats,
    String? promoCode,
  }) {
    final base = seats.fold<double>(0, (sum, s) => sum + s.fareLkr);
    final tax = base * taxRate;
    final normalized = promoCode?.trim().toUpperCase();
    final discount = normalized == promoCodeValue ? base * promoDiscountRate : 0.0;
    final total = (base + tax - discount).clamp(0, double.infinity);
    return (base: base, tax: tax, discount: discount, total: total.toDouble());
  }

  Map<String, dynamic> toPaymentPayload() => {
        'booking_id': bookingId,
        'schedule_id': scheduleId,
        'operator_name': operatorName,
        'route': routeLabel,
        'departure_at': departureAt.toIso8601String(),
        'contact_email': contactEmail,
        'contact_phone': contactPhone,
        'boarding_point': {
          'id': boardingPoint.id,
          'name': boardingPoint.name,
        },
        'dropping_point': {
          'id': droppingPoint.id,
          'name': droppingPoint.name,
        },
        'seats': selectedSeats.map((s) => s.seatNumber).toList(),
        'passengers': passengers.map((p) => p.toPayload()).toList(),
        'pricing': {
          'base_fare_lkr': baseFareLkr,
          'tax_lkr': taxLkr,
          'discount_lkr': discountLkr,
          'total_lkr': totalLkr,
          'promo_code': promoCode,
        },
      };

  @override
  List<Object?> get props => [bookingId, scheduleId, totalLkr, selectedSeats];
}
