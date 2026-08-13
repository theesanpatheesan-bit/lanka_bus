import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lanka_bus/core/utils/formatters.dart';
import 'package:lanka_bus/features/operator_dashboard/data/models/operator_trip_model.dart';
import 'package:lanka_bus/features/operator_dashboard/domain/repositories/operator_repository.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({
    super.key,
    this.scheduleId,
    this.trip,
  });

  final String? scheduleId;
  final OperatorTripModel? trip;

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  bool _handling = false;
  bool _permissionGranted = false;
  String? _permissionError;

  @override
  void initState() {
    super.initState();
    _ensureCamera();
  }

  Future<void> _ensureCamera() async {
    final status = await Permission.camera.request();
    if (!mounted) return;
    setState(() {
      _permissionGranted = status.isGranted;
      _permissionError = status.isGranted
          ? null
          : 'Camera permission is required to scan tickets.';
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handling) return;
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;
    final raw = barcodes.first.rawValue;
    if (raw == null || raw.isEmpty) return;

    setState(() => _handling = true);
    final repo = context.read<OperatorRepository>();
    await _controller.stop();

    final parsed = _parseTicketQr(raw);
    TicketScanResult result;
    try {
      result = await repo.verifyTicket(
        bookingId: parsed.bookingId,
        pnr: parsed.pnr,
      );
    } catch (error) {
      result = TicketScanResult(
        type: TicketScanResultType.invalid,
        message: error.toString(),
      );
    }

    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _ScanResultSheet(result: result),
    );

    if (!mounted) return;
    setState(() => _handling = false);
    await _controller.start();
  }

  ({String? bookingId, String? pnr}) _parseTicketQr(String raw) {
    // Expected: LANKA_BUS|<PNR>|<bookingId>
    final parts = raw.split('|');
    if (parts.length >= 3 && parts.first == 'LANKA_BUS') {
      return (pnr: parts[1], bookingId: parts[2]);
    }
    if (raw.toUpperCase().startsWith('SLBUS-')) {
      return (pnr: raw.toUpperCase(), bookingId: null);
    }
    // UUID-looking booking id
    if (RegExp(
      r'^[0-9a-fA-F-]{36}$',
    ).hasMatch(raw)) {
      return (pnr: null, bookingId: raw);
    }
    return (pnr: raw, bookingId: null);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.trip == null
            ? 'Scan tickets'
            : 'Scan · ${widget.trip!.routeLabel}'),
      ),
      body: !_permissionGranted
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_permissionError ?? 'Camera unavailable'),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _ensureCamera,
                      child: const Text('Grant camera permission'),
                    ),
                    TextButton(
                      onPressed: openAppSettings,
                      child: const Text('Open settings'),
                    ),
                  ],
                ),
              ),
            )
          : Stack(
              children: [
                MobileScanner(
                  controller: _controller,
                  onDetect: _onDetect,
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    width: double.infinity,
                    color: Colors.black54,
                    padding: const EdgeInsets.all(16),
                    child: const Text(
                      'Align the M-Ticket QR inside the frame',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
                if (_handling)
                  const ColoredBox(
                    color: Colors.black45,
                    child: Center(child: CircularProgressIndicator()),
                  ),
              ],
            ),
    );
  }
}

class _ScanResultSheet extends StatelessWidget {
  const _ScanResultSheet({required this.result});

  final TicketScanResult result;

  @override
  Widget build(BuildContext context) {
    final (color, icon, title) = switch (result.type) {
      TicketScanResultType.valid => (
          Colors.green,
          Icons.check_circle,
          'Valid / Approved',
        ),
      TicketScanResultType.alreadyScanned => (
          Colors.amber.shade800,
          Icons.warning_amber_rounded,
          'Already Scanned',
        ),
      TicketScanResultType.invalid => (
          Colors.red,
          Icons.cancel,
          'Invalid Ticket',
        ),
    };

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        20 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 56),
          const SizedBox(height: 8),
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          Text(result.message, textAlign: TextAlign.center),
          if (result.passengerName != null) ...[
            const SizedBox(height: 12),
            Text(result.passengerName!,
                style: const TextStyle(fontWeight: FontWeight.w700)),
            if (result.seatNumbers.isNotEmpty)
              Text('Seats: ${result.seatNumbers.join(', ')}'),
            if (result.boardingPoint != null && result.boardingPoint!.isNotEmpty)
              Text('Boarding: ${result.boardingPoint}'),
            if (result.pnr != null) Text('PNR: ${result.pnr}'),
            if (result.type == TicketScanResultType.alreadyScanned &&
                result.boardedAt != null)
              Text(
                'Passenger already boarded at ${Formatters.time(result.boardedAt!)}',
                textAlign: TextAlign.center,
              ),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Scan next'),
          ),
        ],
      ),
    );
  }
}
