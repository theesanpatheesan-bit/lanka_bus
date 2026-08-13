import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lanka_bus/core/router/app_router.dart';
import 'package:lanka_bus/core/utils/formatters.dart';
import 'package:lanka_bus/features/seat_booking/data/models/confirmed_booking_model.dart';
import 'package:lanka_bus/features/seat_booking/presentation/utils/ticket_utils.dart';
import 'package:qr_flutter/qr_flutter.dart';

class MTicketScreen extends StatelessWidget {
  const MTicketScreen({super.key, required this.ticket});

  final ConfirmedBookingModel ticket;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('M-Ticket'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            tooltip: 'Home',
            onPressed: () => context.go(AppRouter.passengerHome),
            icon: const Icon(Icons.home_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: scheme.outlineVariant),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          ticket.pnr,
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          ticket.bookingStatus.toUpperCase(),
                          style: const TextStyle(
                            color: Color(0xFF166534),
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    ticket.paymentStatus == 'pending'
                        ? 'Payment: Pay at bus'
                        : 'Payment: ${ticket.paymentStatus.toUpperCase()}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: QrImageView(
                      data: ticket.qrPayload,
                      size: 180,
                      backgroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      'Scan for boarding',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ),
                  const Divider(height: 32),
                  Text(
                    ticket.routeLabel,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(Formatters.date(ticket.departureAt)),
                  Text(
                    '${Formatters.time(ticket.departureAt)} → ${Formatters.time(ticket.arrivalAt)}',
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Seats: ${ticket.seatsLabel}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 16),
                  _PointTile(
                    title: 'Boarding',
                    place: ticket.boardingPoint,
                    time: Formatters.time(ticket.boardingTime),
                    onNavigate: () =>
                        TicketUtils.openMapsForPoint(ticket.boardingPoint),
                  ),
                  const SizedBox(height: 8),
                  _PointTile(
                    title: 'Dropping',
                    place: ticket.droppingPoint,
                    time: Formatters.time(ticket.droppingTime),
                    onNavigate: () =>
                        TicketUtils.openMapsForPoint(ticket.droppingPoint),
                  ),
                  const Divider(height: 32),
                  Text('Operator: ${ticket.operatorName}'),
                  Text('Bus: ${ticket.busNumber} · ${ticket.busRegistration}'),
                  Text('Support: ${ticket.operatorPhone}'),
                  const SizedBox(height: 12),
                  Text('Passenger: ${ticket.passengerName}'),
                  Text('Phone: ${ticket.passengerPhone}'),
                  if (ticket.passengerEmail != null)
                    Text('Email: ${ticket.passengerEmail}'),
                  const SizedBox(height: 12),
                  Text(
                    'Total ${Formatters.priceLkr(ticket.totalAmountLkr)}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: scheme.primary,
                        ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: (ticket.scheduleId == null && ticket.busId == null)
                ? null
                : () => context.push(
                      '${AppRouter.liveTracking}'
                      '?scheduleId=${ticket.scheduleId ?? ''}'
                      '&busId=${ticket.busId ?? ''}'
                      '&boarding=${Uri.encodeComponent(ticket.boardingPoint)}',
                    ),
            icon: const Icon(Icons.my_location),
            label: const Text('Track live bus'),
          ),
          const SizedBox(height: 8),
          FilledButton.tonalIcon(
            onPressed: () => TicketUtils.shareTicketPdf(ticket),
            icon: const Icon(Icons.picture_as_pdf_outlined),
            label: const Text('Export / share PDF'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => TicketUtils.shareTicketText(ticket),
            icon: const Icon(Icons.share),
            label: const Text('Share via WhatsApp / SMS'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => TicketUtils.printTicket(ticket),
            child: const Text('Print ticket'),
          ),
        ],
      ),
    );
  }
}

class _PointTile extends StatelessWidget {
  const _PointTile({
    required this.title,
    required this.place,
    required this.time,
    required this.onNavigate,
  });

  final String title;
  final String place;
  final String time;
  final VoidCallback onNavigate;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              Text(place),
              Text(time, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        TextButton.icon(
          onPressed: onNavigate,
          icon: const Icon(Icons.map_outlined, size: 18),
          label: const Text('Navigate'),
        ),
      ],
    );
  }
}
