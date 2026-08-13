-- =============================================================================
-- Lanka Bus — Confirm booking payment (atomic) + PNR format
-- =============================================================================

CREATE OR REPLACE FUNCTION public.confirm_booking_payment(
    p_booking_id UUID,
    p_payment_method TEXT,
    p_payment_reference TEXT,
    p_gateway_status TEXT DEFAULT 'success'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_booking RECORD;
    v_pnr TEXT;
    v_payment_status payment_status;
    v_booking_status booking_status;
    v_result JSONB;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    PERFORM public.release_expired_seat_locks();

    SELECT * INTO v_booking
    FROM public.bookings
    WHERE id = p_booking_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Booking not found';
    END IF;

    IF v_booking.passenger_user_id <> v_user_id AND NOT public.is_admin() THEN
        RAISE EXCEPTION 'Not allowed to confirm this booking';
    END IF;

    IF v_booking.booking_status = 'confirmed'
       AND v_booking.payment_status IN ('paid', 'pending') THEN
        -- Idempotent return of existing confirmation
        RETURN public.build_booking_ticket_json(p_booking_id);
    END IF;

    IF v_booking.booking_status = 'cancelled' THEN
        RAISE EXCEPTION 'Booking was cancelled';
    END IF;

    -- Ensure seats are still locked for this booking
    IF NOT EXISTS (
        SELECT 1 FROM public.booked_seats
        WHERE booking_id = p_booking_id AND status = 'locked'
    ) THEN
        RAISE EXCEPTION 'Seat lock expired. Please select seats again.';
    END IF;

    v_pnr := 'SLBUS-' || to_char(NOW() AT TIME ZONE 'Asia/Colombo', 'YYYY')
        || '-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 4));

    IF lower(p_gateway_status) = 'success' AND lower(p_payment_method) = 'cash_on_boarding' THEN
        v_payment_status := 'pending';
        v_booking_status := 'confirmed';
    ELSIF lower(p_gateway_status) = 'success' THEN
        v_payment_status := 'paid';
        v_booking_status := 'confirmed';
    ELSIF lower(p_gateway_status) = 'pending' THEN
        v_payment_status := 'pending';
        v_booking_status := 'pending';
    ELSE
        RAISE EXCEPTION 'Payment not successful';
    END IF;

    UPDATE public.bookings
    SET
        booking_ref = v_pnr,
        payment_method = p_payment_method,
        payment_reference = p_payment_reference,
        payment_status = v_payment_status,
        booking_status = v_booking_status,
        updated_at = NOW()
    WHERE id = p_booking_id;

    UPDATE public.booked_seats
    SET
        status = 'booked',
        locked_until = NULL,
        updated_at = NOW()
    WHERE booking_id = p_booking_id
      AND status = 'locked';

    RETURN public.build_booking_ticket_json(p_booking_id);
END;
$$;

CREATE OR REPLACE FUNCTION public.build_booking_ticket_json(p_booking_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_json JSONB;
BEGIN
    SELECT jsonb_build_object(
        'booking_id', b.id,
        'pnr', b.booking_ref,
        'booking_status', b.booking_status,
        'payment_status', b.payment_status,
        'payment_method', b.payment_method,
        'payment_reference', b.payment_reference,
        'total_amount_lkr', b.total_amount_lkr,
        'base_fare_lkr', b.base_fare_lkr,
        'tax_lkr', b.tax_lkr,
        'discount_lkr', b.discount_lkr,
        'promo_code', b.promo_code,
        'passenger_name', b.passenger_name,
        'passenger_phone', b.passenger_phone,
        'passenger_email', b.passenger_email,
        'booked_at', b.booked_at,
        'schedule_id', s.id,
        'departure_at', s.departure_at,
        'arrival_at', s.arrival_at,
        'origin_city', r.origin_city,
        'destination_city', r.destination_city,
        'origin_terminal', r.origin_terminal,
        'destination_terminal', r.destination_terminal,
        'operator_name', COALESCE(o.trade_name, o.company_name),
        'operator_phone', o.contact_phone,
        'bus_number', bus.bus_number,
        'bus_registration', bus.registration_no,
        'bus_type', bus.bus_type,
        'boarding_point', COALESCE(bp.name, r.origin_terminal, r.origin_city),
        'dropping_point', COALESCE(dp.name, r.destination_terminal, r.destination_city),
        'boarding_offset_minutes', COALESCE(bp.offset_minutes, 0),
        'dropping_offset_minutes', COALESCE(dp.offset_minutes, 0),
        'seats', (
            SELECT COALESCE(jsonb_agg(
                jsonb_build_object(
                    'seat_number', bs.seat_number,
                    'passenger_name', bs.passenger_name,
                    'passenger_gender', bs.passenger_gender,
                    'fare_lkr', bs.fare_lkr
                )
                ORDER BY bs.seat_number
            ), '[]'::jsonb)
            FROM public.booked_seats bs
            WHERE bs.booking_id = b.id AND bs.status = 'booked'
        )
    )
    INTO v_json
    FROM public.bookings b
    JOIN public.bus_schedules s ON s.id = b.schedule_id
    JOIN public.routes r ON r.id = s.route_id
    JOIN public.operators o ON o.id = s.operator_id
    JOIN public.buses bus ON bus.id = s.bus_id
    LEFT JOIN public.route_points bp ON bp.id = b.boarding_point_id
    LEFT JOIN public.route_points dp ON dp.id = b.dropping_point_id
    WHERE b.id = p_booking_id;

    IF v_json IS NULL THEN
        RAISE EXCEPTION 'Booking ticket not found';
    END IF;

    RETURN v_json;
END;
$$;

GRANT EXECUTE ON FUNCTION public.confirm_booking_payment TO authenticated;
GRANT EXECUTE ON FUNCTION public.build_booking_ticket_json TO authenticated;
