import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lanka_bus/core/utils/formatters.dart';
import 'package:lanka_bus/features/operator_dashboard/data/models/operator_trip_model.dart';
import 'package:lanka_bus/features/operator_dashboard/domain/repositories/operator_repository.dart';
import 'package:lanka_bus/features/operator_dashboard/presentation/utils/manifest_pdf.dart';
import 'package:lanka_bus/features/seat_booking/data/models/seat_model.dart';
import 'package:lanka_bus/features/seat_booking/presentation/widgets/seat_grid.dart';
import 'package:lanka_bus/features/seat_booking/presentation/widgets/seat_legend.dart';

class SeatChartScreen extends StatefulWidget {
  const SeatChartScreen({
    super.key,
    required this.scheduleId,
    this.trip,
  });

  final String scheduleId;
  final OperatorTripModel? trip;

  @override
  State<SeatChartScreen> createState() => _SeatChartScreenState();
}

class _SeatChartScreenState extends State<SeatChartScreen> {
  List<SeatModel> _seats = [];
  List<ManifestPassengerModel> _manifest = [];
  bool _loading = true;
  String? _error;
  SeatDeck _deck = SeatDeck.lower;
  bool _listMode = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = context.read<OperatorRepository>();
      final seats = await repo.fetchSeatLayout(widget.scheduleId);
      final manifest = await repo.fetchManifest(widget.scheduleId);
      if (!mounted) return;
      setState(() {
        _seats = seats;
        _manifest = manifest;
        _loading = false;
        _deck = seats.any((s) => s.deck == SeatDeck.upper)
            ? _deck
            : SeatDeck.lower;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  ManifestPassengerModel? _passengerForSeat(String seatNumber) {
    for (final p in _manifest) {
      if (p.seatNumber == seatNumber) return p;
    }
    return null;
  }

  Future<void> _openPassenger(ManifestPassengerModel passenger) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return _PassengerDetailsSheet(
          passenger: passenger,
          onToggleBoarded: (boarded) async {
            await context.read<OperatorRepository>().markSeatBoarded(
                  bookedSeatId: passenger.bookedSeatId,
                  boarded: boarded,
                );
            if (context.mounted) Navigator.pop(context);
            await _load();
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasUpper = _seats.any((s) => s.deck == SeatDeck.upper);
    final title = widget.trip?.routeLabel ?? 'Seat chart';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            tooltip: _listMode ? 'Seat grid' : 'Passenger list',
            onPressed: () => setState(() => _listMode = !_listMode),
            icon: Icon(_listMode ? Icons.grid_view : Icons.list_alt),
          ),
          IconButton(
            tooltip: 'Share / PDF manifest',
            onPressed: _manifest.isEmpty
                ? null
                : () => ManifestPdf.share(
                      trip: widget.trip,
                      passengers: _manifest,
                    ),
            icon: const Icon(Icons.picture_as_pdf_outlined),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!),
                      FilledButton(onPressed: _load, child: const Text('Retry')),
                    ],
                  ),
                )
              : Column(
                  children: [
                    if (widget.trip != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        child: Text(
                          '${widget.trip!.busRegistration} · '
                          '${widget.trip!.bookedSeats}/${widget.trip!.totalSeats} booked · '
                          '${_manifest.where((p) => p.isBoarded).length} boarded',
                        ),
                      ),
                    if (!_listMode && hasUpper)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        child: SegmentedButton<SeatDeck>(
                          segments: const [
                            ButtonSegment(
                              value: SeatDeck.lower,
                              label: Text('Lower'),
                            ),
                            ButtonSegment(
                              value: SeatDeck.upper,
                              label: Text('Upper'),
                            ),
                          ],
                          selected: {_deck},
                          onSelectionChanged: (v) =>
                              setState(() => _deck = v.first),
                        ),
                      ),
                    if (!_listMode)
                      const Padding(
                        padding: EdgeInsets.all(12),
                        child: SeatLegend(),
                      ),
                    Expanded(
                      child: _listMode
                          ? ListView.separated(
                              padding: const EdgeInsets.all(16),
                              itemCount: _manifest.length,
                              separatorBuilder: (context, index) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final p = _manifest[index];
                                return ListTile(
                                  title: Text(
                                    '${p.seatNumber} · ${p.passengerName}',
                                  ),
                                  subtitle: Text(
                                    '${p.boardingPoint} · ${p.paymentStatus}'
                                    '${p.isBoarded ? ' · Boarded' : ''}',
                                  ),
                                  trailing: Icon(
                                    p.isBoarded
                                        ? Icons.check_circle
                                        : Icons.event_seat,
                                    color: p.isBoarded ? Colors.green : null,
                                  ),
                                  onTap: () => _openPassenger(p),
                                );
                              },
                            )
                          : SeatGrid(
                              seats: _seats
                                  .where((s) => s.deck == _deck)
                                  .toList(),
                              selectedSeatNumbers: {
                                for (final p in _manifest)
                                  if (p.isBoarded) p.seatNumber,
                              },
                              allowOccupiedTap: true,
                              onSeatTap: (seatNumber) {
                                final passenger =
                                    _passengerForSeat(seatNumber);
                                if (passenger != null) {
                                  _openPassenger(passenger);
                                }
                              },
                            ),
                    ),
                  ],
                ),
    );
  }
}

class _PassengerDetailsSheet extends StatefulWidget {
  const _PassengerDetailsSheet({
    required this.passenger,
    required this.onToggleBoarded,
  });

  final ManifestPassengerModel passenger;
  final Future<void> Function(bool boarded) onToggleBoarded;

  @override
  State<_PassengerDetailsSheet> createState() => _PassengerDetailsSheetState();
}

class _PassengerDetailsSheetState extends State<_PassengerDetailsSheet> {
  late bool _boarded;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _boarded = widget.passenger.isBoarded;
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.passenger;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        20 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Seat ${p.seatNumber}',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          Text('Name: ${p.passengerName}'),
          Text('Phone: ${p.passengerPhone}'),
          Text('PNR: ${p.pnr}'),
          Text('Boarding: ${p.boardingPoint}'),
          Text('Dropping: ${p.droppingPoint}'),
          Text('Payment: ${p.paymentStatus}'),
          if (p.boardedAt != null)
            Text('Boarded at: ${Formatters.dateTime(p.boardedAt!)}'),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Boarded'),
            value: _boarded,
            onChanged: _saving
                ? null
                : (value) async {
                    setState(() {
                      _boarded = value;
                      _saving = true;
                    });
                    await widget.onToggleBoarded(value);
                    if (mounted) setState(() => _saving = false);
                  },
          ),
        ],
      ),
    );
  }
}
