import 'package:lanka_bus/core/utils/formatters.dart';
import 'package:lanka_bus/features/operator_dashboard/data/models/operator_trip_model.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class ManifestPdf {
  ManifestPdf._();

  static Future<void> share({
    required OperatorTripModel? trip,
    required List<ManifestPassengerModel> passengers,
  }) async {
    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Text(
            'Passenger Manifest',
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
          ),
          if (trip != null) ...[
            pw.SizedBox(height: 8),
            pw.Text(trip.routeLabel),
            pw.Text(
              '${Formatters.date(trip.departureAt)} · ${Formatters.time(trip.departureAt)}',
            ),
            pw.Text('Bus ${trip.busRegistration}'),
          ],
          pw.SizedBox(height: 16),
          pw.TableHelper.fromTextArray(
            headers: const [
              'Seat',
              'Passenger',
              'Phone',
              'Boarding',
              'Payment',
              'Boarded',
            ],
            data: [
              for (final p in passengers)
                [
                  p.seatNumber,
                  p.passengerName,
                  p.passengerPhone,
                  p.boardingPoint,
                  p.paymentStatus,
                  p.isBoarded ? 'Yes' : 'No',
                ],
            ],
          ),
        ],
      ),
    );

    final bytes = await doc.save();
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'manifest-${trip?.scheduleId ?? 'trip'}.pdf',
    );
  }
}
