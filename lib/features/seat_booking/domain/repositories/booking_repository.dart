import 'package:lanka_bus/features/seat_booking/data/models/confirmed_booking_model.dart';
import 'package:lanka_bus/features/seat_booking/data/services/payment_service.dart';

abstract class BookingRepository {
  /// Confirms payment and finalizes seats (`locked` → `booked`).
  Future<ConfirmedBookingModel> confirmPayment({
    required String bookingId,
    required PaymentResult paymentResult,
  });

  Future<ConfirmedBookingModel> fetchTicket(String bookingId);
}
