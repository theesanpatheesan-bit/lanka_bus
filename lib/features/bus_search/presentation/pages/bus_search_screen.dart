import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lanka_bus/core/router/app_router.dart';
import 'package:lanka_bus/core/utils/formatters.dart';
import 'package:lanka_bus/features/bus_search/presentation/bloc/bus_search_bloc.dart';

class BusSearchScreen extends StatefulWidget {
  const BusSearchScreen({super.key});

  @override
  State<BusSearchScreen> createState() => _BusSearchScreenState();
}

class _BusSearchScreenState extends State<BusSearchScreen> {
  @override
  void initState() {
    super.initState();
    context.read<BusSearchBloc>().add(const BusSearchCitiesRequested());
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final tomorrow = todayDate.add(const Duration(days: 1));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Search buses'),
      ),
      body: BlocConsumer<BusSearchBloc, BusSearchState>(
        listenWhen: (prev, next) =>
            prev.status != next.status &&
            (next.status == BusSearchStatus.success ||
                next.status == BusSearchStatus.empty ||
                next.status == BusSearchStatus.failure),
        listener: (context, state) {
          if (state.status == BusSearchStatus.failure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.errorMessage ?? 'Search failed'),
              ),
            );
            return;
          }
          if (state.status == BusSearchStatus.success ||
              state.status == BusSearchStatus.empty) {
            context.push(AppRouter.busResults);
          }
        },
        builder: (context, state) {
          final loading = state.status == BusSearchStatus.loading;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Where are you going?',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Popular routes: Colombo → Kandy, Galle, Jaffna',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurface.withValues(alpha: 0.7),
                      ),
                ),
                const SizedBox(height: 24),
                _CityField(
                  label: 'From',
                  value: state.originCity,
                  cities: state.cities,
                  icon: Icons.trip_origin,
                  onChanged: (city) => context
                      .read<BusSearchBloc>()
                      .add(BusSearchOriginChanged(city)),
                ),
                const SizedBox(height: 8),
                Align(
                  child: IconButton.filledTonal(
                    tooltip: 'Swap cities',
                    onPressed: () => context
                        .read<BusSearchBloc>()
                        .add(const BusSearchCitiesSwapped()),
                    icon: const Icon(Icons.swap_vert_rounded),
                  ),
                ),
                const SizedBox(height: 8),
                _CityField(
                  label: 'To',
                  value: state.destinationCity,
                  cities: state.cities,
                  icon: Icons.location_on_outlined,
                  onChanged: (city) => context
                      .read<BusSearchBloc>()
                      .add(BusSearchDestinationChanged(city)),
                ),
                const SizedBox(height: 20),
                Text(
                  'Departure date',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: state.departureDate,
                      firstDate: todayDate,
                      lastDate: todayDate.add(const Duration(days: 60)),
                    );
                    if (picked != null && context.mounted) {
                      context
                          .read<BusSearchBloc>()
                          .add(BusSearchDateChanged(picked));
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.calendar_month_outlined),
                      border: OutlineInputBorder(),
                    ),
                    child: Text(Formatters.date(state.departureDate)),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Today'),
                      selected: _isSameDay(state.departureDate, todayDate),
                      onSelected: (_) => context
                          .read<BusSearchBloc>()
                          .add(BusSearchDateChanged(todayDate)),
                    ),
                    ChoiceChip(
                      label: const Text('Tomorrow'),
                      selected: _isSameDay(state.departureDate, tomorrow),
                      onSelected: (_) => context
                          .read<BusSearchBloc>()
                          .add(BusSearchDateChanged(tomorrow)),
                    ),
                  ],
                ),
                if (state.validationMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    state.validationMessage!,
                    style: TextStyle(color: scheme.error),
                  ),
                ],
                const SizedBox(height: 28),
                ElevatedButton.icon(
                  onPressed: loading
                      ? null
                      : () => context
                          .read<BusSearchBloc>()
                          .add(const BusSearchSubmitted()),
                  icon: loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.search),
                  label: Text(loading ? 'Searching…' : 'Search Buses'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _CityField extends StatelessWidget {
  const _CityField({
    required this.label,
    required this.value,
    required this.cities,
    required this.icon,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<String> cities;
  final IconData icon;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      key: ValueKey('$label-$value'),
      initialValue: cities.contains(value) ? value : null,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: const OutlineInputBorder(),
      ),
      items: cities
          .map(
            (city) => DropdownMenuItem(
              value: city,
              child: Text(city),
            ),
          )
          .toList(),
      onChanged: (city) {
        if (city != null) onChanged(city);
      },
    );
  }
}
