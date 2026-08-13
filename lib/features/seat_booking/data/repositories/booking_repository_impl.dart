import 'package:lanka_bus/core/network/supabase_client.dart';
import 'package:lanka_bus/features/seat_booking/data/models/confirmed_booking_model.dart';
import 'package:lanka_bus/features/seat_booking/data/services/payment_service.dart';
import 'package:lanka_bus/features/seat_booking/domain/repositories/booking_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BookingRepositoryImpl implements BookingRepository {
  BookingRepositoryImpl({SupabaseClient? client})
      : _client = client ?? SupabaseClientProvider.client;

  final SupabaseClient _client;

  @override
  Future<ConfirmedBookingModel> confirmPayment({
    required String bookingId,
    required PaymentResult paymentResult,
  }) async {
    if (paymentResult.status == PaymentGatewayStatus.cancelled) {
      throw StateError('Payment was cancelled.');
    }
    if (paymentResult.status == PaymentGatewayStatus.failed) {
      throw StateError(paymentResult.message ?? 'Payment failed.');
    }

    final gatewayStatus = switch (paymentResult.status) {
      PaymentGatewayStatus.success => 'success',
      PaymentGatewayStatus.pending => 'pending',
      PaymentGatewayStatus.cancelled => 'cancelled',
      PaymentGatewayStatus.failed => 'failed',
    };

    final raw = await _client.rpc(
      'confirm_booking_payment',
      params: {
        'p_booking_id': bookingId,
        'p_payment_method': paymentResult.method.code,
        'p_payment_reference': paymentResult.transactionId,
        'p_gateway_status': gatewayStatus,
      },
    );

    return ConfirmedBookingModel.fromJson(
      Map<String, dynamic>.from(raw as Map),
    );
  }

  @override
  Future<ConfirmedBookingModel> fetchTicket(String bookingId) async {
    final raw = await _client.rpc(
      'build_booking_ticket_json',
      params: {'p_booking_id': bookingId},
    );
    return ConfirmedBookingModel.fromJson(
      Map<String, dynamic>.from(raw as Map),
    );
  }
}
