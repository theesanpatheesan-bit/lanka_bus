import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:lanka_bus/app.dart';
import 'package:lanka_bus/core/network/supabase_client.dart';
import 'package:lanka_bus/core/theme/app_theme.dart';
import 'package:lanka_bus/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:lanka_bus/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:lanka_bus/features/auth/domain/repositories/auth_repository.dart';
import 'package:lanka_bus/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:lanka_bus/features/bus_search/data/datasources/bus_search_remote_datasource.dart';
import 'package:lanka_bus/features/bus_search/data/repositories/bus_search_repository_impl.dart';
import 'package:lanka_bus/features/bus_search/domain/repositories/bus_search_repository.dart';
import 'package:lanka_bus/features/bus_search/presentation/bloc/bus_search_bloc.dart';
import 'package:lanka_bus/features/operator_dashboard/data/repositories/admin_repository_impl.dart';
import 'package:lanka_bus/features/operator_dashboard/data/repositories/operator_repository_impl.dart';
import 'package:lanka_bus/features/operator_dashboard/data/services/driver_gps_service.dart';
import 'package:lanka_bus/features/operator_dashboard/domain/repositories/admin_repository.dart';
import 'package:lanka_bus/features/operator_dashboard/domain/repositories/operator_repository.dart';
import 'package:lanka_bus/features/live_tracking/data/repositories/live_tracking_repository_impl.dart';
import 'package:lanka_bus/features/live_tracking/domain/repositories/live_tracking_repository.dart';
import 'package:lanka_bus/features/seat_booking/data/datasources/seat_booking_remote_datasource.dart';
import 'package:lanka_bus/features/seat_booking/data/repositories/booking_repository_impl.dart';
import 'package:lanka_bus/features/seat_booking/data/repositories/seat_booking_repository_impl.dart';
import 'package:lanka_bus/features/seat_booking/data/services/payment_service.dart';
import 'package:lanka_bus/features/seat_booking/domain/repositories/booking_repository.dart';
import 'package:lanka_bus/features/seat_booking/domain/repositories/seat_booking_repository.dart';
import 'package:lanka_bus/features/seat_booking/presentation/bloc/seat_booking_bloc.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: '.env');
  final ready = await SupabaseClientProvider.initialize();

  if (!ready) {
    runApp(const _ConfigRequiredApp());
    return;
  }

  final AuthRepository authRepository =
      AuthRepositoryImpl(AuthRemoteDataSource());
  final BusSearchRepository busSearchRepository =
      BusSearchRepositoryImpl(BusSearchRemoteDataSource());
  final SeatBookingRepository seatBookingRepository =
      SeatBookingRepositoryImpl(SeatBookingRemoteDataSource());
  final BookingRepository bookingRepository = BookingRepositoryImpl();
  final PaymentService paymentService = MockPaymentService();
  final OperatorRepository operatorRepository = OperatorRepositoryImpl();
  final AdminRepository adminRepository = AdminRepositoryImpl();
  final LiveTrackingRepository liveTrackingRepository =
      LiveTrackingRepositoryImpl();
  final driverGpsService = DriverGpsService(operatorRepository);

  runApp(
    MultiRepositoryProvider(
      providers: [
        RepositoryProvider<AuthRepository>.value(value: authRepository),
        RepositoryProvider<BusSearchRepository>.value(
          value: busSearchRepository,
        ),
        RepositoryProvider<SeatBookingRepository>.value(
          value: seatBookingRepository,
        ),
        RepositoryProvider<BookingRepository>.value(value: bookingRepository),
        RepositoryProvider<PaymentService>.value(value: paymentService),
        RepositoryProvider<OperatorRepository>.value(value: operatorRepository),
        RepositoryProvider<AdminRepository>.value(value: adminRepository),
        RepositoryProvider<LiveTrackingRepository>.value(
          value: liveTrackingRepository,
        ),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (_) => AuthBloc(authRepository)..add(const AuthStarted()),
          ),
          BlocProvider(
            create: (_) => BusSearchBloc(busSearchRepository),
          ),
          BlocProvider(
            create: (_) => SeatBookingBloc(seatBookingRepository),
          ),
        ],
        child: ChangeNotifierProvider<DriverGpsService>.value(
          value: driverGpsService,
          child: const LankaBusApp(),
        ),
      ),
    ),
  );
}

class _ConfigRequiredApp extends StatelessWidget {
  const _ConfigRequiredApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const Scaffold(
        body: Padding(
          padding: EdgeInsets.all(24),
          child: Center(
            child: Text(
              'Configure Supabase\n\n'
              '1. Copy .env.example to .env\n'
              '2. Set SUPABASE_URL and SUPABASE_ANON_KEY\n'
              '3. Run the SQL migrations in supabase/migrations/\n'
              '4. Enable Phone auth (OTP) in Supabase Auth providers\n'
              '5. Restart the app',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
