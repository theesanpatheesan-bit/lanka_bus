import 'package:flutter/material.dart';
import 'package:lanka_bus/features/bus_search/domain/entities/bus_search_query.dart';

Future<BusSearchFilters?> showSearchFilterBottomSheet({
  required BuildContext context,
  required BusSearchFilters initial,
  required List<({String id, String name})> operators,
}) {
  return showModalBottomSheet<BusSearchFilters>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) {
      return SearchFilterBottomSheet(
        initial: initial,
        operators: operators,
      );
    },
  );
}

class SearchFilterBottomSheet extends StatefulWidget {
  const SearchFilterBottomSheet({
    super.key,
    required this.initial,
    required this.operators,
  });

  final BusSearchFilters initial;
  final List<({String id, String name})> operators;

  @override
  State<SearchFilterBottomSheet> createState() =>
      _SearchFilterBottomSheetState();
}

class _SearchFilterBottomSheetState extends State<SearchFilterBottomSheet> {
  late BusSortOption _sort;
  late Set<String> _busTypes;
  late Set<String> _operatorIds;
  late Set<DepartureTimeSlot> _slots;

  @override
  void initState() {
    super.initState();
    _sort = widget.initial.sort;
    _busTypes = {...widget.initial.busTypeKeys};
    _operatorIds = {...widget.initial.operatorIds};
    _slots = {...widget.initial.timeSlots};
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 16 + bottom),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Sort & filter',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 16),
              Text(
                'Sort by',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _chip(
                    selected: _sort == BusSortOption.priceLowHigh,
                    label: 'Price: Low → High',
                    onTap: () =>
                        setState(() => _sort = BusSortOption.priceLowHigh),
                  ),
                  _chip(
                    selected: _sort == BusSortOption.departureEarlyLate,
                    label: 'Departure: Early → Late',
                    onTap: () => setState(
                      () => _sort = BusSortOption.departureEarlyLate,
                    ),
                  ),
                  _chip(
                    selected: _sort == BusSortOption.ratingHighLow,
                    label: 'Rating: High → Low',
                    onTap: () =>
                        setState(() => _sort = BusSortOption.ratingHighLow),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'Bus type',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final entry in const [
                    ('ac', 'AC'),
                    ('non_ac', 'Non-AC'),
                    ('sleeper', 'Sleeper'),
                    ('seater', 'Seater'),
                  ])
                    FilterChip(
                      label: Text(entry.$2),
                      selected: _busTypes.contains(entry.$1),
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _busTypes.add(entry.$1);
                          } else {
                            _busTypes.remove(entry.$1);
                          }
                        });
                      },
                    ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'Departure time',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final slot in DepartureTimeSlot.values)
                    FilterChip(
                      label: Text('${slot.label} (${slot.subtitle})'),
                      selected: _slots.contains(slot),
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _slots.add(slot);
                          } else {
                            _slots.remove(slot);
                          }
                        });
                      },
                    ),
                ],
              ),
              if (widget.operators.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text(
                  'Operators',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                ...widget.operators.map(
                  (op) => CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(op.name),
                    value: _operatorIds.contains(op.id),
                    onChanged: (checked) {
                      setState(() {
                        if (checked == true) {
                          _operatorIds.add(op.id);
                        } else {
                          _operatorIds.remove(op.id);
                        }
                      });
                    },
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _sort = BusSortOption.departureEarlyLate;
                          _busTypes.clear();
                          _operatorIds.clear();
                          _slots.clear();
                        });
                      },
                      child: const Text('Reset'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        Navigator.of(context).pop(
                          BusSearchFilters(
                            sort: _sort,
                            busTypeKeys: _busTypes,
                            operatorIds: _operatorIds,
                            timeSlots: _slots,
                          ),
                        );
                      },
                      child: const Text('Apply'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip({
    required bool selected,
    required String label,
    required VoidCallback onTap,
  }) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }
}
