import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lanka_bus/core/router/app_router.dart';
import 'package:lanka_bus/core/utils/formatters.dart';
import 'package:lanka_bus/features/seat_booking/data/models/booking_summary_model.dart';
import 'package:lanka_bus/features/seat_booking/data/services/payment_service.dart';
import 'package:lanka_bus/features/seat_booking/domain/repositories/booking_repository.dart';

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key, required this.summary});

  final BookingSummaryModel summary;

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  PaymentMethodType _method = PaymentMethodType.card;
  bool _processing = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final summary = widget.summary;

    return Scaffold(
      appBar: AppBar(title: const Text('Payment')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            Formatters.priceLkr(summary.totalLkr),
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 4),
          Text('${summary.routeLabel} · ${summary.operatorName}'),
          Text(
            'Seats: ${summary.selectedSeats.map((s) => s.seatNumber).join(', ')}',
          ),
          const SizedBox(height: 20),
          Text(
            'Choose payment method',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          for (final method in PaymentMethodType.values)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: _method == method
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: ListTile(
                leading: Icon(_iconFor(method)),
                title: Text(method.label),
                subtitle: Text(method.subtitle),
                trailing: Icon(
                  _method == method
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: Theme.of(context).colorScheme.primary,
                ),
                onTap: _processing
                    ? null
                    : () => setState(() {
                          _method = method;
                          _error = null;
                        }),
              ),
            ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            'Sandbox mode — no real charges. Use Card or PayHere for instant '
            'confirmation, or Pay at bus to confirm with pending payment.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: _processing ? null : _pay,
            child: _processing
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    _method == PaymentMethodType.cashOnBoarding
                        ? 'Confirm pay-at-bus booking'
                        : 'Pay ${Formatters.priceLkr(summary.totalLkr)}',
                  ),
          ),
        ),
      ),
    );
  }

  IconData _iconFor(PaymentMethodType method) => switch (method) {
        PaymentMethodType.card => Icons.credit_card,
        PaymentMethodType.payHere => Icons.account_balance_wallet_outlined,
        PaymentMethodType.cashOnBoarding => Icons.directions_bus_filled,
      };

  Future<void> _pay() async {
    setState(() {
      _processing = true;
      _error = null;
    });

    final paymentService = context.read<PaymentService>();
    final bookingRepository = context.read<BookingRepository>();

    try {
      if (_method == PaymentMethodType.payHere) {
        final proceed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('PayHere sandbox'),
            content: const Text(
              'This simulates a redirect to PayHere / WEBXPAY. '
              'Continue as if payment succeeded?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Return success'),
              ),
            ],
          ),
        );
        if (proceed != true) {
          setState(() {
            _processing = false;
            _error = 'Payment cancelled.';
          });
          return;
        }
      }

      final result = await paymentService.processPayment(
        PaymentRequest(
          bookingId: summary.bookingId,
          amountLkr: summary.totalLkr,
          customerEmail: summary.contactEmail,
          customerPhone: summary.contactPhone,
          method: _method,
          description: summary.routeLabel,
        ),
      );

      if (result.status == PaymentGatewayStatus.cancelled) {
        setState(() {
          _processing = false;
          _error = 'Payment cancelled.';
        });
        return;
      }
      if (result.status == PaymentGatewayStatus.failed) {
        setState(() {
          _processing = false;
          _error = result.message ?? 'Payment failed.';
        });
        return;
      }

      final ticket = await bookingRepository.confirmPayment(
        bookingId: summary.bookingId,
        paymentResult: result,
      );

      if (!mounted) return;
      context.go(AppRouter.mTicket, extra: ticket);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _processing = false;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  BookingSummaryModel get summary => widget.summary;
}
