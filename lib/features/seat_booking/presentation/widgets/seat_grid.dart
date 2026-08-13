import 'package:flutter/material.dart';
import 'package:lanka_bus/features/seat_booking/data/models/seat_model.dart';

class SeatGrid extends StatelessWidget {
  const SeatGrid({
    super.key,
    required this.seats,
    required this.selectedSeatNumbers,
    required this.onSeatTap,
    this.allowOccupiedTap = false,
  });

  final List<SeatModel> seats;
  final Set<String> selectedSeatNumbers;
  final ValueChanged<String> onSeatTap;
  final bool allowOccupiedTap;

  @override
  Widget build(BuildContext context) {
    if (seats.isEmpty) {
      return const Center(child: Text('No seats on this deck'));
    }

    final maxRow =
        seats.map((s) => s.rowIndex).reduce((a, b) => a > b ? a : b);
    final maxCol =
        seats.map((s) => s.columnIndex).reduce((a, b) => a > b ? a : b);

    final byPos = <String, SeatModel>{
      for (final s in seats) '${s.rowIndex}:${s.columnIndex}': s,
    };

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        children: [
          for (var row = 0; row <= maxRow; row++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var col = 0; col <= maxCol; col++)
                    _SeatCell(
                      seat: byPos['$row:$col'],
                      selected: byPos['$row:$col'] != null &&
                          selectedSeatNumbers
                              .contains(byPos['$row:$col']!.seatNumber),
                      onTap: onSeatTap,
                      allowOccupiedTap: allowOccupiedTap,
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _SeatCell extends StatelessWidget {
  const _SeatCell({
    required this.seat,
    required this.selected,
    required this.onTap,
    this.allowOccupiedTap = false,
  });

  final SeatModel? seat;
  final bool selected;
  final ValueChanged<String> onTap;
  final bool allowOccupiedTap;

  @override
  Widget build(BuildContext context) {
    if (seat == null) {
      return const SizedBox(width: 52, height: 52);
    }

    if (seat!.kind == SeatKind.aisle) {
      return const SizedBox(width: 28, height: 52);
    }

    if (seat!.kind == SeatKind.driver) {
      return const SizedBox(
        width: 52,
        height: 52,
        child: Icon(Icons.airline_seat_recline_extra, color: Colors.blueGrey),
      );
    }

    final visual =
        selected ? SeatVisualStatus.selected : seat!.visualStatus;

    final (bg, border, fg) = switch (visual) {
      SeatVisualStatus.available => (
          Colors.transparent,
          const Color(0xFF6B7280),
          const Color(0xFF111827),
        ),
      SeatVisualStatus.selected => (
          const Color(0xFF0B6E4F),
          const Color(0xFF0B6E4F),
          Colors.white,
        ),
      SeatVisualStatus.booked || SeatVisualStatus.locked => (
          const Color(0xFF9CA3AF),
          const Color(0xFF9CA3AF),
          Colors.white,
        ),
      SeatVisualStatus.femaleAvailable => (
          const Color(0xFFFDF2F8),
          const Color(0xFFDB2777),
          const Color(0xFF9D174D),
        ),
      SeatVisualStatus.femaleBooked => (
          const Color(0xFFF9A8D4),
          const Color(0xFFDB2777),
          Colors.white,
        ),
    };

    final enabled = seat!.kind != SeatKind.aisle &&
        seat!.kind != SeatKind.driver &&
        ((seat!.isSelectable && !seat!.isOccupied) ||
            (allowOccupiedTap && seat!.isOccupied));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: InkWell(
        onTap: enabled ? () => onTap(seat!.seatNumber) : null,
        borderRadius: BorderRadius.circular(10),
        child: Ink(
          width: 52,
          height: 56,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: border, width: 1.4),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (selected)
                const Icon(Icons.check, size: 14, color: Colors.white)
              else
                Text(
                  seat!.seatNumber,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: fg,
                  ),
                ),
              Text(
                selected ? seat!.seatNumber : '${seat!.fareLkr.round()}',
                style: TextStyle(
                  fontSize: 9,
                  color: fg.withValues(alpha: 0.9),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
