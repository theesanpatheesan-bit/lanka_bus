import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lanka_bus/core/constants/sri_lanka_cities.dart';
import 'package:lanka_bus/core/utils/formatters.dart';
import 'package:lanka_bus/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:lanka_bus/features/operator_dashboard/data/models/admin_models.dart';
import 'package:lanka_bus/features/operator_dashboard/domain/repositories/admin_repository.dart';

enum _AdminNav {
  overview,
  fleet,
  routes,
  operators,
}

/// Responsive admin / operator web portal with sidebar + content panes.
class AdminWebDashboard extends StatefulWidget {
  const AdminWebDashboard({super.key});

  @override
  State<AdminWebDashboard> createState() => _AdminWebDashboardState();
}

class _AdminWebDashboardState extends State<AdminWebDashboard> {
  _AdminNav _nav = _AdminNav.overview;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 980;
    final user = context.watch<AuthBloc>().state.user;

    final content = switch (_nav) {
      _AdminNav.overview => const _OverviewTab(),
      _AdminNav.fleet => const _FleetTab(),
      _AdminNav.routes => const _RoutesTab(),
      _AdminNav.operators => const _OperatorsTab(),
    };

    final sidebar = _Sidebar(
      selected: _nav,
      onSelect: (n) => setState(() => _nav = n),
      userName: user?.fullName ?? 'Admin',
      onSignOut: () =>
          context.read<AuthBloc>().add(const AuthSignOutRequested()),
    );

    if (!wide) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Lanka Bus Admin'),
          actions: [
            IconButton(
              onPressed: () =>
                  context.read<AuthBloc>().add(const AuthSignOutRequested()),
              icon: const Icon(Icons.logout),
            ),
          ],
        ),
        drawer: Drawer(child: sidebar),
        body: content,
      );
    }

    return Scaffold(
      body: Row(
        children: [
          SizedBox(width: 260, child: sidebar),
          const VerticalDivider(width: 1),
          Expanded(child: content),
        ],
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.selected,
    required this.onSelect,
    required this.userName,
    required this.onSignOut,
  });

  final _AdminNav selected;
  final ValueChanged<_AdminNav> onSelect;
  final String userName;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: scheme.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
              child: Text(
                'Lanka Bus',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: scheme.primary,
                    ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text('Admin · $userName'),
            ),
            const SizedBox(height: 16),
            _NavTile(
              icon: Icons.dashboard_outlined,
              label: 'Overview',
              selected: selected == _AdminNav.overview,
              onTap: () => onSelect(_AdminNav.overview),
            ),
            _NavTile(
              icon: Icons.directions_bus_outlined,
              label: 'Bus & Fleet',
              selected: selected == _AdminNav.fleet,
              onTap: () => onSelect(_AdminNav.fleet),
            ),
            _NavTile(
              icon: Icons.route_outlined,
              label: 'Routes & Schedules',
              selected: selected == _AdminNav.routes,
              onTap: () => onSelect(_AdminNav.routes),
            ),
            _NavTile(
              icon: Icons.verified_user_outlined,
              label: 'Operator Onboarding',
              selected: selected == _AdminNav.operators,
              onTap: () => onSelect(_AdminNav.operators),
            ),
            const Spacer(),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Sign out'),
              onTap: onSignOut,
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        selected: selected,
        selectedTileColor: scheme.primary.withValues(alpha: 0.12),
        leading: Icon(icon),
        title: Text(label),
        onTap: onTap,
      ),
    );
  }
}

class _OverviewTab extends StatefulWidget {
  const _OverviewTab();

  @override
  State<_OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends State<_OverviewTab> {
  AdminMetrics? _metrics;
  String? _error;
  bool _loading = true;

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
      final m = await context.read<AdminRepository>().fetchMetrics();
      if (!mounted) return;
      setState(() {
        _metrics = m;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = _metrics;
    return _PaneScaffold(
      title: 'Overview Analytics',
      onRefresh: _load,
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : m == null
                  ? const SizedBox.shrink()
                  : LayoutBuilder(
                      builder: (context, c) {
                        final cols = c.maxWidth > 1100
                            ? 4
                            : c.maxWidth > 700
                                ? 2
                                : 1;
                        return GridView.count(
                          crossAxisCount: cols,
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 16,
                          childAspectRatio: 1.6,
                          children: [
                            _MetricCard(
                              title: 'Bookings today',
                              value: '${m.bookingsToday}',
                              icon: Icons.confirmation_number_outlined,
                            ),
                            _MetricCard(
                              title: 'Revenue (LKR)',
                              value: Formatters.priceLkr(m.revenueTodayLkr),
                              icon: Icons.payments_outlined,
                            ),
                            _MetricCard(
                              title: 'Active buses',
                              value: '${m.activeBuses}',
                              icon: Icons.sensors,
                            ),
                            _MetricCard(
                              title: 'Commission earned',
                              value: Formatters.priceLkr(m.commissionTodayLkr),
                              icon: Icons.account_balance_wallet_outlined,
                            ),
                            _MetricCard(
                              title: 'Pending operators',
                              value: '${m.pendingOperators}',
                              icon: Icons.hourglass_top,
                            ),
                            _MetricCard(
                              title: 'Active operators',
                              value: '${m.activeOperators}',
                              icon: Icons.storefront_outlined,
                            ),
                          ],
                        );
                      },
                    ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: scheme.primary),
            const Spacer(),
            Text(title, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 4),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FleetTab extends StatefulWidget {
  const _FleetTab();

  @override
  State<_FleetTab> createState() => _FleetTabState();
}

class _FleetTabState extends State<_FleetTab> {
  List<AdminBusItem> _buses = [];
  List<AdminOperatorItem> _operators = [];
  bool _loading = true;
  String? _error;

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
      final repo = context.read<AdminRepository>();
      final buses = await repo.listBuses();
      final ops = await repo.listOperators(status: 'active');
      if (!mounted) return;
      setState(() {
        _buses = buses;
        _operators = ops;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _showAddBus() async {
    if (_operators.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Approve an operator before adding buses')),
      );
      return;
    }
    final numberCtrl = TextEditingController();
    final regCtrl = TextEditingController();
    final seatsCtrl = TextEditingController(text: '40');
    var operatorId = _operators.first.id;
    var busType = 'ac';
    var layout = 'seater';

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Add bus'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: operatorId,
                    decoration: const InputDecoration(labelText: 'Operator'),
                    items: _operators
                        .map(
                          (o) => DropdownMenuItem(
                            value: o.id,
                            child: Text(o.tradeName ?? o.companyName),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setLocal(() => operatorId = v!),
                  ),
                  TextField(
                    controller: numberCtrl,
                    decoration: const InputDecoration(labelText: 'Bus number'),
                  ),
                  TextField(
                    controller: regCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Registration no'),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: busType,
                    decoration: const InputDecoration(labelText: 'AC type'),
                    items: const [
                      DropdownMenuItem(value: 'ac', child: Text('AC')),
                      DropdownMenuItem(value: 'non_ac', child: Text('Non-AC')),
                      DropdownMenuItem(value: 'luxury', child: Text('Luxury')),
                      DropdownMenuItem(
                        value: 'sleeper',
                        child: Text('Sleeper'),
                      ),
                      DropdownMenuItem(
                        value: 'semi_sleeper',
                        child: Text('Semi-sleeper'),
                      ),
                    ],
                    onChanged: (v) => setLocal(() => busType = v!),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: layout,
                    decoration: const InputDecoration(labelText: 'Layout'),
                    items: const [
                      DropdownMenuItem(value: 'seater', child: Text('Seater 2+2')),
                      DropdownMenuItem(
                        value: 'sleeper',
                        child: Text('Sleeper berths'),
                      ),
                    ],
                    onChanged: (v) {
                      setLocal(() {
                        layout = v!;
                        if (layout == 'sleeper' && busType == 'ac') {
                          busType = 'sleeper';
                        }
                      });
                    },
                  ),
                  TextField(
                    controller: seatsCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Total seats'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (ok != true || !mounted) return;
    try {
      final type = layout == 'sleeper' && busType != 'sleeper'
          ? 'sleeper'
          : busType;
      await context.read<AdminRepository>().upsertBus(
            operatorId: operatorId,
            busNumber: numberCtrl.text.trim(),
            registrationNo: regCtrl.text.trim(),
            busType: type,
            totalSeats: int.tryParse(seatsCtrl.text.trim()) ?? 40,
            amenities: type.contains('ac') || type == 'luxury'
                ? ['ac', 'usb']
                : ['usb'],
            generateLayout: true,
          );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return _PaneScaffold(
      title: 'Bus & Fleet Management',
      onRefresh: _load,
      action: FilledButton.icon(
        onPressed: _showAddBus,
        icon: const Icon(Icons.add),
        label: const Text('Add bus'),
      ),
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : ListView.separated(
                  itemCount: _buses.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final b = _buses[i];
                    return ListTile(
                      leading: const Icon(Icons.directions_bus),
                      title: Text('${b.busNumber} · ${b.registrationNo}'),
                      subtitle: Text(
                        '${b.operatorName ?? b.operatorId} · '
                        '${b.busType} · ${b.totalSeats} seats · '
                        'layout ${b.layoutSeatCount}',
                      ),
                      trailing: Chip(
                        label: Text(b.isActive ? 'Active' : 'Inactive'),
                      ),
                    );
                  },
                ),
    );
  }
}

class _RoutesTab extends StatefulWidget {
  const _RoutesTab();

  @override
  State<_RoutesTab> createState() => _RoutesTabState();
}

class _RoutesTabState extends State<_RoutesTab> {
  List<AdminRouteItem> _routes = [];
  List<AdminBusItem> _buses = [];
  bool _loading = true;
  String? _error;

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
      final repo = context.read<AdminRepository>();
      final routes = await repo.listRoutes();
      final buses = await repo.listBuses();
      if (!mounted) return;
      setState(() {
        _routes = routes;
        _buses = buses;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _createRoute() async {
    var origin = SriLankaCities.all.first;
    var destination = SriLankaCities.all[1];
    final terminalO = TextEditingController();
    final terminalD = TextEditingController();
    final distance = TextEditingController(text: '115');
    final duration = TextEditingController(text: '210');
    final stopName = TextEditingController();
    final stopOffset = TextEditingController(text: '30');

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Create route'),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: origin,
                    decoration: const InputDecoration(labelText: 'Origin'),
                    items: SriLankaCities.all
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (v) => setLocal(() => origin = v!),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: destination,
                    decoration: const InputDecoration(labelText: 'Destination'),
                    items: SriLankaCities.all
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (v) => setLocal(() => destination = v!),
                  ),
                  TextField(
                    controller: terminalO,
                    decoration:
                        const InputDecoration(labelText: 'Origin terminal'),
                  ),
                  TextField(
                    controller: terminalD,
                    decoration:
                        const InputDecoration(labelText: 'Destination terminal'),
                  ),
                  TextField(
                    controller: distance,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Distance km'),
                  ),
                  TextField(
                    controller: duration,
                    keyboardType: TextInputType.number,
                    decoration:
                        const InputDecoration(labelText: 'Duration minutes'),
                  ),
                  const Divider(),
                  TextField(
                    controller: stopName,
                    decoration: const InputDecoration(
                      labelText: 'Optional boarding stop',
                    ),
                  ),
                  TextField(
                    controller: stopOffset,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Stop offset minutes',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    try {
      final repo = context.read<AdminRepository>();
      final id = await repo.upsertRoute(
        originCity: origin,
        destinationCity: destination,
        originTerminal: terminalO.text.trim().isEmpty
            ? null
            : terminalO.text.trim(),
        destinationTerminal: terminalD.text.trim().isEmpty
            ? null
            : terminalD.text.trim(),
        distanceKm: double.tryParse(distance.text.trim()),
        durationMinutes: int.tryParse(duration.text.trim()),
      );
      if (stopName.text.trim().isNotEmpty) {
        await repo.upsertRoutePoint(
          routeId: id,
          pointType: 'boarding',
          name: stopName.text.trim(),
          offsetMinutes: int.tryParse(stopOffset.text.trim()) ?? 0,
          sortOrder: 1,
        );
      }
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _scheduleTrip(AdminRouteItem route) async {
    if (_buses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Need at least one bus')),
      );
      return;
    }
    var busId = _buses.first.id;
    var operatorId = _buses.first.operatorId;
    final price = TextEditingController(text: '1200');
    final days = TextEditingController(text: '7');
    var departure = DateTime.now().add(const Duration(hours: 4));
    departure = DateTime(
      departure.year,
      departure.month,
      departure.day,
      departure.hour,
      0,
    );
    var arrival = departure.add(
      Duration(minutes: route.estimatedDurationMinutes ?? 180),
    );

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text('Schedule · ${route.label}'),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: busId,
                  decoration: const InputDecoration(labelText: 'Bus'),
                  items: _buses
                      .map(
                        (b) => DropdownMenuItem(
                          value: b.id,
                          child: Text('${b.busNumber} · ${b.operatorName}'),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    final bus = _buses.firstWhere((b) => b.id == v);
                    setLocal(() {
                      busId = bus.id;
                      operatorId = bus.operatorId;
                    });
                  },
                ),
                TextField(
                  controller: price,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Base price LKR'),
                ),
                TextField(
                  controller: days,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Recurring days (1–30)',
                  ),
                ),
                const SizedBox(height: 8),
                Text('Departs ${Formatters.dateTime(departure)}'),
                TextButton(
                  onPressed: () async {
                    final d = await showDatePicker(
                      context: context,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 90)),
                      initialDate: departure,
                    );
                    if (d == null || !context.mounted) return;
                    final t = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.fromDateTime(departure),
                    );
                    if (t == null) return;
                    setLocal(() {
                      departure = DateTime(
                        d.year,
                        d.month,
                        d.day,
                        t.hour,
                        t.minute,
                      );
                      arrival = departure.add(
                        Duration(
                          minutes: route.estimatedDurationMinutes ?? 180,
                        ),
                      );
                    });
                  },
                  child: const Text('Pick departure'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Create trips'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    try {
      final count = await context.read<AdminRepository>().createSchedule(
            routeId: route.id,
            busId: busId,
            operatorId: operatorId,
            departureAt: departure,
            arrivalAt: arrival,
            basePriceLkr: double.tryParse(price.text.trim()) ?? 1000,
            recurringDays: (int.tryParse(days.text.trim()) ?? 1).clamp(1, 30),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Created $count schedule(s)')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return _PaneScaffold(
      title: 'Route & Schedule Management',
      onRefresh: _load,
      action: FilledButton.icon(
        onPressed: _createRoute,
        icon: const Icon(Icons.add_road),
        label: const Text('New route'),
      ),
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : ListView.builder(
                  itemCount: _routes.length,
                  itemBuilder: (context, i) {
                    final r = _routes[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ExpansionTile(
                        title: Text(r.label),
                        subtitle: Text(
                          '${r.distanceKm?.toStringAsFixed(0) ?? '—'} km · '
                          '${r.estimatedDurationMinutes ?? '—'} min · '
                          '${r.points.length} stops',
                        ),
                        children: [
                          ...r.points.map(
                            (p) => ListTile(
                              dense: true,
                              leading: Icon(
                                p.pointType == 'boarding'
                                    ? Icons.login
                                    : Icons.logout,
                              ),
                              title: Text(p.name),
                              trailing: Text('+${p.offsetMinutes}m'),
                            ),
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: FilledButton.tonal(
                                onPressed: () => _scheduleTrip(r),
                                child: const Text('Schedule recurring trips'),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}

class _OperatorsTab extends StatefulWidget {
  const _OperatorsTab();

  @override
  State<_OperatorsTab> createState() => _OperatorsTabState();
}

class _OperatorsTabState extends State<_OperatorsTab> {
  List<AdminOperatorItem> _items = [];
  bool _loading = true;
  String? _error;
  String _filter = 'pending';

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
      final items = await context.read<AdminRepository>().listOperators(
            status: _filter == 'all' ? null : _filter,
          );
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _setStatus(AdminOperatorItem op, String status) async {
    try {
      await context.read<AdminRepository>().setOperatorStatus(
            operatorId: op.id,
            status: status,
          );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return _PaneScaffold(
      title: 'Operator Onboarding',
      onRefresh: _load,
      action: SegmentedButton<String>(
        segments: const [
          ButtonSegment(value: 'pending', label: Text('Pending')),
          ButtonSegment(value: 'active', label: Text('Active')),
          ButtonSegment(value: 'all', label: Text('All')),
        ],
        selected: {_filter},
        onSelectionChanged: (s) {
          setState(() => _filter = s.first);
          _load();
        },
      ),
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _items.isEmpty
                  ? const Center(child: Text('No operators in this filter'))
                  : ListView.separated(
                      itemCount: _items.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final op = _items[i];
                        return ListTile(
                          isThreeLine: true,
                          title: Text(op.tradeName ?? op.companyName),
                          subtitle: Text(
                            'BR: ${op.brNumber ?? '—'} · VAT: ${op.vatNumber ?? '—'}\n'
                            '${op.contactEmail ?? ''} · ${op.contactPhone ?? ''}\n'
                            '${op.addressLine1 ?? ''} ${op.city ?? ''}\n'
                            'Owner: ${op.ownerName ?? '—'} (${op.ownerEmail ?? '—'})',
                          ),
                          trailing: Wrap(
                            spacing: 8,
                            children: [
                              Chip(label: Text(op.status)),
                              if (op.status == 'pending') ...[
                                FilledButton(
                                  onPressed: () => _setStatus(op, 'active'),
                                  child: const Text('Approve'),
                                ),
                                OutlinedButton(
                                  onPressed: () => _setStatus(op, 'rejected'),
                                  child: const Text('Reject'),
                                ),
                              ],
                              if (op.status == 'active')
                                OutlinedButton(
                                  onPressed: () => _setStatus(op, 'suspended'),
                                  child: const Text('Suspend'),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
    );
  }
}

class _PaneScaffold extends StatelessWidget {
  const _PaneScaffold({
    required this.title,
    required this.child,
    required this.onRefresh,
    this.action,
  });

  final String title;
  final Widget child;
  final Future<void> Function() onRefresh;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              IconButton(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh),
              ),
              if (action != null) ...[
                const SizedBox(width: 8),
                action!,
              ],
            ],
          ),
          const SizedBox(height: 16),
          Expanded(child: child),
        ],
      ),
    );
  }
}
