-- =============================================================================
-- Operator/Conductor trip APIs, boarding verification, GPS upsert
-- Run AFTER after 008_boarded_seat_status.sql has been applied.
-- =============================================================================

DROP INDEX IF EXISTS uq_booked_seats_active_seat;
CREATE UNIQUE INDEX uq_booked_seats_active_seat
    ON public.booked_seats (schedule_id, seat_number)
    WHERE status IN ('reserved', 'locked', 'booked', 'boarded');

CREATE OR REPLACE FUNCTION public.sync_schedule_available_seats()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    target_schedule UUID;
    booked_count INTEGER;
    total INTEGER;
BEGIN
    target_schedule := COALESCE(NEW.schedule_id, OLD.schedule_id);

    SELECT COUNT(*) INTO booked_count
    FROM public.booked_seats
    WHERE schedule_id = target_schedule
      AND status IN ('reserved', 'locked', 'booked', 'boarded');

    SELECT b.total_seats INTO total
    FROM public.bus_schedules s
    JOIN public.buses b ON b.id = s.bus_id
    WHERE s.id = target_schedule;

    UPDATE public.bus_schedules
    SET available_seats = GREATEST(total - booked_count, 0),
        updated_at = NOW()
    WHERE id = target_schedule;

    RETURN COALESCE(NEW, OLD);
END;
$$;

CREATE OR REPLACE FUNCTION public.staff_operator_ids()
RETURNS SETOF UUID
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT o.id
    FROM public.operators o
    WHERE o.owner_user_id = auth.uid()
    UNION
    SELECT s.operator_id
    FROM public.operator_staff s
    WHERE s.user_id = auth.uid() AND s.is_active = TRUE;
$$;

CREATE OR REPLACE FUNCTION public.list_operator_trips(
    p_from TIMESTAMPTZ,
    p_to TIMESTAMPTZ
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    RETURN COALESCE((
        SELECT jsonb_agg(row_data ORDER BY departure_at)
        FROM (
            SELECT
                s.departure_at,
                jsonb_build_object(
                    'schedule_id', s.id,
                    'bus_id', s.bus_id,
                    'operator_id', s.operator_id,
                    'departure_at', s.departure_at,
                    'arrival_at', s.arrival_at,
                    'status', s.status,
                    'base_price_lkr', s.base_price_lkr,
                    'origin_city', r.origin_city,
                    'destination_city', r.destination_city,
                    'bus_number', b.bus_number,
                    'bus_registration', b.registration_no,
                    'total_seats', b.total_seats,
                    'booked_seats', (
                        SELECT COUNT(*)::int
                        FROM public.booked_seats bs
                        WHERE bs.schedule_id = s.id
                          AND bs.status IN ('booked', 'boarded')
                    ),
                    'boarded_seats', (
                        SELECT COUNT(*)::int
                        FROM public.booked_seats bs
                        WHERE bs.schedule_id = s.id
                          AND bs.status = 'boarded'
                    ),
                    'revenue_lkr', (
                        SELECT COALESCE(SUM(bk.total_amount_lkr), 0)
                        FROM public.bookings bk
                        WHERE bk.schedule_id = s.id
                          AND bk.booking_status = 'confirmed'
                    )
                ) AS row_data
            FROM public.bus_schedules s
            JOIN public.routes r ON r.id = s.route_id
            JOIN public.buses b ON b.id = s.bus_id
            WHERE s.operator_id IN (SELECT public.staff_operator_ids())
              AND s.status <> 'cancelled'
              AND s.departure_at >= p_from
              AND s.departure_at < p_to
        ) q
    ), '[]'::jsonb);
END;
$$;

CREATE OR REPLACE FUNCTION public.get_trip_manifest(p_schedule_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_op UUID;
BEGIN
    SELECT operator_id INTO v_op FROM public.bus_schedules WHERE id = p_schedule_id;
    IF v_op IS NULL OR v_op NOT IN (SELECT public.staff_operator_ids()) THEN
        IF NOT public.is_admin() THEN
            RAISE EXCEPTION 'Not allowed';
        END IF;
    END IF;

    RETURN COALESCE((
        SELECT jsonb_agg(jsonb_build_object(
            'booked_seat_id', bs.id,
            'seat_number', bs.seat_number,
            'seat_layout_id', bs.seat_layout_id,
            'status', bs.status,
            'boarded_at', bs.boarded_at,
            'fare_lkr', bs.fare_lkr,
            'passenger_name', COALESCE(bs.passenger_name, bk.passenger_name),
            'passenger_phone', bk.passenger_phone,
            'passenger_gender', bs.passenger_gender,
            'payment_status', bk.payment_status,
            'booking_id', bk.id,
            'pnr', bk.booking_ref,
            'boarding_point', COALESCE(bp.name, ''),
            'dropping_point', COALESCE(dp.name, '')
        ) ORDER BY bs.seat_number)
        FROM public.booked_seats bs
        JOIN public.bookings bk ON bk.id = bs.booking_id
        LEFT JOIN public.route_points bp ON bp.id = bk.boarding_point_id
        LEFT JOIN public.route_points dp ON dp.id = bk.dropping_point_id
        WHERE bs.schedule_id = p_schedule_id
          AND bs.status IN ('booked', 'boarded')
    ), '[]'::jsonb);
END;
$$;

CREATE OR REPLACE FUNCTION public.verify_and_board_ticket(
    p_booking_id UUID DEFAULT NULL,
    p_pnr TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_booking RECORD;
    v_already TIMESTAMPTZ;
    v_seats JSONB;
BEGIN
    IF p_booking_id IS NULL AND (p_pnr IS NULL OR trim(p_pnr) = '') THEN
        RAISE EXCEPTION 'Missing booking reference';
    END IF;

    SELECT * INTO v_booking
    FROM public.bookings b
    WHERE (p_booking_id IS NOT NULL AND b.id = p_booking_id)
       OR (p_pnr IS NOT NULL AND b.booking_ref = upper(trim(p_pnr)))
    LIMIT 1
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('result', 'invalid', 'message', 'Booking not found or cancelled');
    END IF;

    IF v_booking.booking_status = 'cancelled' THEN
        RETURN jsonb_build_object('result', 'invalid', 'message', 'Booking was cancelled');
    END IF;

    IF v_booking.booking_status <> 'confirmed' THEN
        RETURN jsonb_build_object('result', 'invalid', 'message', 'Booking is not confirmed');
    END IF;

    IF (SELECT operator_id FROM public.bus_schedules WHERE id = v_booking.schedule_id)
       NOT IN (SELECT public.staff_operator_ids())
       AND NOT public.is_admin() THEN
        RETURN jsonb_build_object('result', 'invalid', 'message', 'Ticket is not for your operator trips');
    END IF;

    SELECT MIN(boarded_at) INTO v_already
    FROM public.booked_seats
    WHERE booking_id = v_booking.id
      AND status = 'boarded'
      AND boarded_at IS NOT NULL;

    SELECT COALESCE(jsonb_agg(jsonb_build_object(
        'seat_number', bs.seat_number,
        'passenger_name', COALESCE(bs.passenger_name, v_booking.passenger_name)
    ) ORDER BY bs.seat_number), '[]'::jsonb)
    INTO v_seats
    FROM public.booked_seats bs
    WHERE bs.booking_id = v_booking.id;

    IF v_already IS NOT NULL THEN
        RETURN jsonb_build_object(
            'result', 'already_scanned',
            'message', 'Passenger already boarded',
            'boarded_at', v_already,
            'booking_id', v_booking.id,
            'pnr', v_booking.booking_ref,
            'passenger_name', v_booking.passenger_name,
            'passenger_phone', v_booking.passenger_phone,
            'boarding_point', COALESCE((SELECT name FROM route_points WHERE id = v_booking.boarding_point_id), ''),
            'seats', v_seats
        );
    END IF;

    UPDATE public.booked_seats
    SET status = 'boarded',
        boarded_at = NOW(),
        updated_at = NOW()
    WHERE booking_id = v_booking.id
      AND status IN ('booked', 'boarded');

    RETURN jsonb_build_object(
        'result', 'valid',
        'message', 'Ticket approved',
        'boarded_at', NOW(),
        'booking_id', v_booking.id,
        'pnr', v_booking.booking_ref,
        'passenger_name', v_booking.passenger_name,
        'passenger_phone', v_booking.passenger_phone,
        'boarding_point', COALESCE((SELECT name FROM route_points WHERE id = v_booking.boarding_point_id), ''),
        'seats', v_seats
    );
END;
$$;

CREATE OR REPLACE FUNCTION public.mark_seat_boarded(
    p_booked_seat_id UUID,
    p_boarded BOOLEAN DEFAULT TRUE
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_schedule UUID;
    v_op UUID;
BEGIN
    SELECT schedule_id INTO v_schedule FROM public.booked_seats WHERE id = p_booked_seat_id;
    SELECT operator_id INTO v_op FROM public.bus_schedules WHERE id = v_schedule;

    IF v_op NOT IN (SELECT public.staff_operator_ids()) AND NOT public.is_admin() THEN
        RAISE EXCEPTION 'Not allowed';
    END IF;

    IF p_boarded THEN
        UPDATE public.booked_seats
        SET status = 'boarded', boarded_at = COALESCE(boarded_at, NOW()), updated_at = NOW()
        WHERE id = p_booked_seat_id AND status IN ('booked', 'boarded');
    ELSE
        UPDATE public.booked_seats
        SET status = 'booked', boarded_at = NULL, updated_at = NOW()
        WHERE id = p_booked_seat_id AND status = 'boarded';
    END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.upsert_bus_location(
    p_bus_id UUID,
    p_schedule_id UUID,
    p_lat DOUBLE PRECISION,
    p_lng DOUBLE PRECISION,
    p_speed_kmh NUMERIC DEFAULT NULL,
    p_heading NUMERIC DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_op UUID;
BEGIN
    SELECT operator_id INTO v_op FROM public.buses WHERE id = p_bus_id;
    IF v_op IS NULL OR (v_op NOT IN (SELECT public.staff_operator_ids()) AND NOT public.is_admin()) THEN
        RAISE EXCEPTION 'Not allowed to update bus location';
    END IF;

    INSERT INTO public.bus_locations AS loc (
        bus_id, schedule_id, current_latitude, current_longitude,
        speed_kmh, heading_degrees, updated_at
    ) VALUES (
        p_bus_id, p_schedule_id, p_lat, p_lng, p_speed_kmh, p_heading, NOW()
    )
    ON CONFLICT (bus_id) DO UPDATE
    SET schedule_id = EXCLUDED.schedule_id,
        current_latitude = EXCLUDED.current_latitude,
        current_longitude = EXCLUDED.current_longitude,
        speed_kmh = EXCLUDED.speed_kmh,
        heading_degrees = EXCLUDED.heading_degrees,
        updated_at = NOW();

    INSERT INTO public.bus_location_history (bus_id, schedule_id, latitude, longitude, speed_kmh, recorded_at)
    VALUES (p_bus_id, p_schedule_id, p_lat, p_lng, p_speed_kmh, NOW());

    UPDATE public.bus_schedules
    SET status = CASE
            WHEN status = 'scheduled' THEN 'boarding'::schedule_status
            WHEN status = 'boarding' THEN 'departed'::schedule_status
            ELSE status
        END,
        updated_at = NOW()
    WHERE id = p_schedule_id
      AND status IN ('scheduled', 'boarding');
END;
$$;

GRANT EXECUTE ON FUNCTION public.staff_operator_ids TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_operator_trips TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_trip_manifest TO authenticated;
GRANT EXECUTE ON FUNCTION public.verify_and_board_ticket TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_seat_boarded TO authenticated;
GRANT EXECUTE ON FUNCTION public.upsert_bus_location TO authenticated;
