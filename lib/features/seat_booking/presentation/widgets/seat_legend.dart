import 'package:flutter/material.dart';

class SeatLegend extends StatelessWidget {
  const SeatLegend({super.key});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: const [
        _Item(
          color: Colors.transparent,
          border: Color(0xFF6B7280),
          label: 'Available',
        ),
        _Item(color: Color(0xFF0B6E4F), label: 'Selected'),
        _Item(color: Color(0xFF9CA3AF), label: 'Booked'),
        _Item(
          color: Color(0xFFF9A8D4),
          border: Color(0xFFDB2777),
          label: 'Female',
        ),
      ],
    );
  }
}

class _Item extends StatelessWidget {
  const _Item({
    required this.color,
    required this.label,
    this.border,
  });

  final Color color;
  final Color? border;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: border ?? color),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}
