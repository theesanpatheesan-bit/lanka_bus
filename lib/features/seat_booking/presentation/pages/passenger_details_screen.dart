import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lanka_bus/core/router/app_router.dart';
import 'package:lanka_bus/core/utils/formatters.dart';
import 'package:lanka_bus/features/seat_booking/data/models/passenger_model.dart';
import 'package:lanka_bus/features/seat_booking/presentation/bloc/seat_booking_bloc.dart';

class PassengerDetailsScreen extends StatefulWidget {
  const PassengerDetailsScreen({super.key});

  @override
  State<PassengerDetailsScreen> createState() => _PassengerDetailsScreenState();
}

class _PassengerDetailsScreenState extends State<PassengerDetailsScreen> {
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _promoController;

  @override
  void initState() {
    super.initState();
    final state = context.read<SeatBookingBloc>().state;
    _emailController = TextEditingController(text: state.contactEmail);
    _phoneController = TextEditingController(text: state.contactPhone);
    _promoController = TextEditingController(text: state.promoInput);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _phoneController.dispose();
    _promoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<SeatBookingBloc, SeatBookingState>(
      listenWhen: (p, n) =>
          p.status != n.status ||
          p.errorMessage != n.errorMessage ||
          p.promoMessage != n.promoMessage,
      listener: (context, state) {
        if (state.errorMessage != null &&
            state.status == SeatBookingStatus.passengerDetails) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.errorMessage!)),
          );
        }
        if (state.promoMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.promoMessage!)),
          );
        }
        if (state.status == SeatBookingStatus.readyForPayment &&
            state.summary != null) {
          context.push(AppRouter.payment, extra: state.summary);
        }
      },
      builder: (context, state) {
        final pricing = state.pricing;
        final submitting = state.status == SeatBookingStatus.submitting;

        return Scaffold(
          appBar: AppBar(title: const Text('Passenger details')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Contact details',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                onChanged: (value) => context.read<SeatBookingBloc>().add(
                      SeatBookingContactChanged(email: value),
                    ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Mobile phone',
                  prefixIcon: Icon(Icons.phone_android),
                  helperText: 'Sri Lanka mobile preferred (+94…)',
                ),
                onChanged: (value) => context.read<SeatBookingBloc>().add(
                      SeatBookingContactChanged(phone: value),
                    ),
              ),
              const SizedBox(height: 24),
              Text(
                'Passengers',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              for (final passenger in state.passengers) ...[
                _PassengerCard(passenger: passenger),
                const SizedBox(height: 12),
              ],
              Text(
                'Promo code',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _promoController,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        hintText: 'e.g. SRILANKA20',
                      ),
                      onChanged: (value) => context
                          .read<SeatBookingBloc>()
                          .add(SeatBookingPromoChanged(value)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.tonal(
                    onPressed: () => context
                        .read<SeatBookingBloc>()
                        .add(const SeatBookingPromoApplied()),
                    child: const Text('Apply'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _PriceRow('Base fare', pricing.base),
                      _PriceRow('Govt toll / tax (5%)', pricing.tax),
                      if (pricing.discount > 0)
                        _PriceRow('Promo discount', -pricing.discount),
                      const Divider(),
                      _PriceRow('Total', pricing.total, emphasis: true),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 88),
            ],
          ),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton(
                onPressed: submitting
                    ? null
                    : () => context
                        .read<SeatBookingBloc>()
                        .add(const SeatBookingProceedToPayment()),
                child: submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        'Proceed to Payment · ${Formatters.priceLkr(pricing.total)}',
                      ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PassengerCard extends StatelessWidget {
  const _PassengerCard({required this.passenger});

  final PassengerModel passenger;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Seat ${passenger.seatNumber}',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 10),
            TextFormField(
              initialValue: passenger.fullName,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Full name',
              ),
              onChanged: (value) => context.read<SeatBookingBloc>().add(
                    SeatBookingPassengerUpdated(
                      seatNumber: passenger.seatNumber,
                      fullName: value,
                    ),
                  ),
            ),
            const SizedBox(height: 10),
            TextFormField(
              initialValue: passenger.age?.toString() ?? '',
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(3),
              ],
              decoration: const InputDecoration(labelText: 'Age'),
              onChanged: (value) {
                final age = int.tryParse(value);
                context.read<SeatBookingBloc>().add(
                      SeatBookingPassengerUpdated(
                        seatNumber: passenger.seatNumber,
                        age: age,
                      ),
                    );
              },
            ),
            const SizedBox(height: 10),
            Text('Gender', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              children: [
                for (final gender in PassengerGender.values)
                  ChoiceChip(
                    label: Text(gender.label),
                    selected: passenger.gender == gender,
                    onSelected: (_) => context.read<SeatBookingBloc>().add(
                          SeatBookingPassengerUpdated(
                            seatNumber: passenger.seatNumber,
                            gender: gender,
                          ),
                        ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  const _PriceRow(this.label, this.amount, {this.emphasis = false});

  final String label;
  final double amount;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    final style = emphasis
        ? Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            )
        : Theme.of(context).textTheme.bodyMedium;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(Formatters.priceLkr(amount), style: style),
        ],
      ),
    );
  }
}
