import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';

enum PaymentMethodType { card, payHere, cashOnBoarding }

enum PaymentGatewayStatus { success, failed, cancelled, pending }

extension PaymentMethodTypeX on PaymentMethodType {
  String get label => switch (this) {
        PaymentMethodType.card => 'Card (Visa / Mastercard)',
        PaymentMethodType.payHere => 'PayHere / Local gateway',
        PaymentMethodType.cashOnBoarding => 'Pay at bus (cash)',
      };

  String get code => switch (this) {
        PaymentMethodType.card => 'card',
        PaymentMethodType.payHere => 'payhere',
        PaymentMethodType.cashOnBoarding => 'cash_on_boarding',
      };

  String get subtitle => switch (this) {
        PaymentMethodType.card => 'Sandbox card checkout',
        PaymentMethodType.payHere => 'Mock PayHere / WEBXPAY redirect',
        PaymentMethodType.cashOnBoarding => 'Pay conductor when boarding',
      };
}

class PaymentRequest extends Equatable {
  const PaymentRequest({
    required this.bookingId,
    required this.amountLkr,
    required this.customerEmail,
    required this.customerPhone,
    required this.method,
    this.description,
  });

  final String bookingId;
  final double amountLkr;
  final String customerEmail;
  final String customerPhone;
  final PaymentMethodType method;
  final String? description;

  @override
  List<Object?> get props => [bookingId, amountLkr, method];
}

class PaymentResult extends Equatable {
  const PaymentResult({
    required this.status,
    required this.method,
    required this.transactionId,
    this.message,
  });

  final PaymentGatewayStatus status;
  final PaymentMethodType method;
  final String transactionId;
  final String? message;

  bool get isSuccessful =>
      status == PaymentGatewayStatus.success ||
      (method == PaymentMethodType.cashOnBoarding &&
          status == PaymentGatewayStatus.success);

  @override
  List<Object?> get props => [status, method, transactionId, message];
}

/// Abstraction for Sri Lankan / card gateways (PayHere, WEBXPAY, Stripe…).
abstract class PaymentService {
  Future<PaymentResult> processPayment(PaymentRequest request);
}

/// Development sandbox processor — no real charges.
class MockPaymentService implements PaymentService {
  MockPaymentService({this.forceFailCard = false});

  /// Set true in tests to simulate card decline.
  final bool forceFailCard;
  final _uuid = const Uuid();

  @override
  Future<PaymentResult> processPayment(PaymentRequest request) async {
    await Future<void>.delayed(const Duration(milliseconds: 900));

    final txId =
        'TXN-${request.method.code.toUpperCase()}-${_uuid.v4().substring(0, 8).toUpperCase()}';

    switch (request.method) {
      case PaymentMethodType.card:
        if (forceFailCard) {
          return PaymentResult(
            status: PaymentGatewayStatus.failed,
            method: request.method,
            transactionId: txId,
            message: 'Card declined (sandbox).',
          );
        }
        return PaymentResult(
          status: PaymentGatewayStatus.success,
          method: request.method,
          transactionId: txId,
          message: 'Card payment authorized (sandbox).',
        );

      case PaymentMethodType.payHere:
        // Simulates successful return from PayHere / WEBXPAY redirect.
        return PaymentResult(
          status: PaymentGatewayStatus.success,
          method: request.method,
          transactionId: txId,
          message: 'PayHere sandbox payment completed.',
        );

      case PaymentMethodType.cashOnBoarding:
        return PaymentResult(
          status: PaymentGatewayStatus.success,
          method: request.method,
          transactionId: txId,
          message: 'Booking confirmed. Pay cash to the conductor.',
        );
    }
  }
}
