import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:lanka_bus/core/utils/formatters.dart';
import 'package:lanka_bus/features/seat_booking/data/models/confirmed_booking_model.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// PDF export + share helpers for digital M-Tickets.
class TicketUtils {
  TicketUtils._();

  static Future<Uint8List> buildTicketPdf(ConfirmedBookingModel ticket) async {
    final doc = pw.Document();
    final dateFmt = DateFormat('dd MMM yyyy');
    final timeFmt = DateFormat('hh:mm a');

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Lanka Bus M-Ticket',
                style: pw.TextStyle(
                  fontSize: 22,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Text('PNR: ${ticket.pnr}', style: pw.TextStyle(fontSize: 16)),
              pw.Text('Status: ${ticket.bookingStatus.toUpperCase()}'),
              pw.SizedBox(height: 16),
              pw.Text(
                ticket.routeLabel,
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(dateFmt.format(ticket.departureAt)),
              pw.Text(
                'Dep ${timeFmt.format(ticket.departureAt)} → Arr ${timeFmt.format(ticket.arrivalAt)}',
              ),
              pw.SizedBox(height: 12),
              pw.Text('Seats: ${ticket.seatsLabel}'),
              pw.Text('Boarding: ${ticket.boardingPoint} (${timeFmt.format(ticket.boardingTime)})'),
              pw.Text('Dropping: ${ticket.droppingPoint} (${timeFmt.format(ticket.droppingTime)})'),
              pw.SizedBox(height: 12),
              pw.Text('Operator: ${ticket.operatorName}'),
              pw.Text('Bus: ${ticket.busNumber} · ${ticket.busRegistration}'),
              pw.Text('Support: ${ticket.operatorPhone}'),
              pw.SizedBox(height: 12),
              pw.Text('Passenger: ${ticket.passengerName}'),
              pw.Text('Phone: ${ticket.passengerPhone}'),
              if (ticket.passengerEmail != null)
                pw.Text('Email: ${ticket.passengerEmail}'),
              pw.SizedBox(height: 12),
              pw.Text('Total: ${Formatters.priceLkr(ticket.totalAmountLkr)}'),
              pw.Text('Payment: ${ticket.paymentStatus} · ${ticket.paymentMethod ?? '-'}'),
              pw.SizedBox(height: 16),
              pw.BarcodeWidget(
                barcode: pw.Barcode.qrCode(),
                data: ticket.qrPayload,
                width: 140,
                height: 140,
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                'Show this QR to the conductor. Booking ID: ${ticket.bookingId}',
                style: const pw.TextStyle(fontSize: 10),
              ),
            ],
          );
        },
      ),
    );

    return doc.save();
  }

  static Future<void> shareTicketPdf(ConfirmedBookingModel ticket) async {
    final bytes = await buildTicketPdf(ticket);
    await Printing.sharePdf(
      bytes: bytes,
      filename: '${ticket.pnr}.pdf',
    );
  }

  static Future<void> printTicket(ConfirmedBookingModel ticket) async {
    final bytes = await buildTicketPdf(ticket);
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  /// Opens the system share sheet (WhatsApp / SMS / etc. when installed).
  static Future<void> shareTicketText(ConfirmedBookingModel ticket) async {
    final timeFmt = DateFormat('hh:mm a');
    final dateFmt = DateFormat('dd MMM yyyy');
    final text = '''
Lanka Bus M-Ticket
PNR: ${ticket.pnr}
Status: ${ticket.bookingStatus.toUpperCase()}
${ticket.routeLabel}
${dateFmt.format(ticket.departureAt)} · ${timeFmt.format(ticket.departureAt)}
Seats: ${ticket.seatsLabel}
Boarding: ${ticket.boardingPoint}
Dropping: ${ticket.droppingPoint}
Passenger: ${ticket.passengerName}
Total: ${Formatters.priceLkr(ticket.totalAmountLkr)}
''';

    await SharePlus.instance.share(
      ShareParams(
        text: text.trim(),
        subject: 'Lanka Bus Ticket ${ticket.pnr}',
      ),
    );
  }

  static Future<void> openMapsForPoint(String placeName) async {
    final query = Uri.encodeComponent('$placeName, Sri Lanka');
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$query',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
