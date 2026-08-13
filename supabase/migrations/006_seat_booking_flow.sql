-- =============================================================================
-- Lanka Bus — Seat booking: points, gender flags, lock RPC, layout seed
-- =============================================================================

ALTER TABLE public.seat_layouts
    ADD COLUMN IF NOT EXISTS reserved_for TEXT NOT NULL DEFAULT 'any'
        CHECK (reserved_for IN ('any', 'female', 'male'));

ALTER TABLE public.booked_seats
    ADD COLUMN IF NOT EXISTS passenger_gender TEXT
        CHECK (passenger_gender IS NULL OR passenger_gender IN ('male', 'female', 'other'));

ALTER TABLE public.bookings
    ADD COLUMN IF NOT EXISTS boarding_point_id UUID,
    ADD COLUMN IF NOT EXISTS dropping_point_id UUID,
    ADD COLUMN IF NOT EXISTS promo_code TEXT,
    ADD COLUMN IF NOT EXISTS discount_lkr NUMERIC(12, 2) NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS tax_lkr NUMERIC(12, 2) NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS base_fare_lkr NUMERIC(12, 2) NOT NULL DEFAULT 0;

-- Boarding / dropping points per route
CREATE TABLE IF NOT EXISTS public.route_points (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    route_id        UUID NOT NULL REFERENCES public.routes(id) ON DELETE CASCADE,
    point_type      TEXT NOT NULL CHECK (point_type IN ('boarding', 'dropping')),
    name            TEXT NOT NULL,
    offset_minutes  INTEGER NOT NULL DEFAULT 0,
    sort_order      SMALLINT NOT NULL DEFAULT 0,
    is_active       BOOLEAN NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_route_points_route
    ON public.route_points(route_id, point_type, sort_order);

ALTER TABLE public.bookings
    DROP CONSTRAINT IF EXISTS bookings_boarding_point_id_fkey,
    DROP CONSTRAINT IF EXISTS bookings_dropping_point_id_fkey;

ALTER TABLE public.bookings
    ADD CONSTRAINT bookings_boarding_point_id_fkey
        FOREIGN KEY (boarding_point_id) REFERENCES public.route_points(id) ON DELETE SET NULL,
    ADD CONSTRAINT bookings_dropping_point_id_fkey
        FOREIGN KEY (dropping_point_id) REFERENCES public.route_points(id) ON DELETE SET NULL;

ALTER TABLE public.route_points ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS route_points_public_read ON public.route_points;
CREATE POLICY route_points_public_read ON public.route_points
    FOR SELECT USING (is_active = TRUE OR public.is_admin());

DROP POLICY IF EXISTS route_points_admin_manage ON public.route_points;
CREATE POLICY route_points_admin_manage ON public.route_points
    FOR ALL USING (public.is_admin());

-- Atomic seat lock: pending booking + locked seats (10 minutes)
CREATE OR REPLACE FUNCTION public.lock_seats_for_checkout(
    p_schedule_id UUID,
    p_seat_numbers TEXT[],
    p_seat_layout_ids UUID[],
    p_fares NUMERIC[],
    p_passenger_name TEXT,
    p_passenger_phone TEXT,
    p_passenger_email TEXT DEFAULT NULL,
    p_lock_minutes INTEGER DEFAULT 10
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_booking_id UUID;
    v_total NUMERIC := 0;
    i INTEGER;
    v_locked_until TIMESTAMPTZ;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    IF p_seat_numbers IS NULL OR array_length(p_seat_numbers, 1) IS NULL THEN
        RAISE EXCEPTION 'No seats selected';
    END IF;

    IF array_length(p_seat_numbers, 1) > 6 THEN
        RAISE EXCEPTION 'Maximum 6 seats per booking';
    END IF;

    PERFORM public.release_expired_seat_locks();

    v_locked_until := NOW() + make_interval(mins => p_lock_minutes);

    FOR i IN 1 .. array_length(p_seat_numbers, 1) LOOP
        v_total := v_total + COALESCE(p_fares[i], 0);
    END LOOP;

    INSERT INTO public.bookings (
        passenger_user_id,
        schedule_id,
        passenger_name,
        passenger_phone,
        passenger_email,
        seat_count,
        total_amount_lkr,
        base_fare_lkr,
        payment_status,
        booking_status
    ) VALUES (
        v_user_id,
        p_schedule_id,
        COALESCE(NULLIF(trim(p_passenger_name), ''), 'Passenger'),
        COALESCE(NULLIF(trim(p_passenger_phone), ''), '+94700000000'),
        p_passenger_email,
        array_length(p_seat_numbers, 1),
        v_total,
        v_total,
        'pending',
        'pending'
    )
    RETURNING id INTO v_booking_id;

    FOR i IN 1 .. array_length(p_seat_numbers, 1) LOOP
        INSERT INTO public.booked_seats (
            booking_id,
            schedule_id,
            seat_layout_id,
            seat_number,
            status,
            locked_until,
            fare_lkr
        ) VALUES (
            v_booking_id,
            p_schedule_id,
            p_seat_layout_ids[i],
            p_seat_numbers[i],
            'locked',
            v_locked_until,
            COALESCE(p_fares[i], 0)
        );
    END LOOP;

    RETURN v_booking_id;
EXCEPTION
    WHEN unique_violation THEN
        RAISE EXCEPTION 'One or more seats were just taken. Please choose different seats.';
END;
$$;

GRANT EXECUTE ON FUNCTION public.lock_seats_for_checkout TO authenticated;
GRANT EXECUTE ON FUNCTION public.release_expired_seat_locks TO authenticated;

-- Seed Colombo→Kandy boarding/dropping points
INSERT INTO public.route_points (route_id, point_type, name, offset_minutes, sort_order)
SELECT r.id, 'boarding', p.name, p.offset_minutes, p.sort_order
FROM public.routes r
CROSS JOIN (VALUES
    ('Bastian Mawatha', 0, 1),
    ('Colombo Fort', 15, 2),
    ('Kadawatha', 40, 3)
) AS p(name, offset_minutes, sort_order)
WHERE r.origin_city = 'Colombo' AND r.destination_city = 'Kandy'
  AND NOT EXISTS (
      SELECT 1 FROM public.route_points rp
      WHERE rp.route_id = r.id AND rp.point_type = 'boarding' AND rp.name = p.name
  );

INSERT INTO public.route_points (route_id, point_type, name, offset_minutes, sort_order)
SELECT r.id, 'dropping', p.name, p.offset_minutes, p.sort_order
FROM public.routes r
CROSS JOIN (VALUES
    ('Mawathagama', -45, 1),
    ('Kurunegala Junction', -25, 2),
    ('Kandy Clock Tower', 0, 3)
) AS p(name, offset_minutes, sort_order)
WHERE r.origin_city = 'Colombo' AND r.destination_city = 'Kandy'
  AND NOT EXISTS (
      SELECT 1 FROM public.route_points rp
      WHERE rp.route_id = r.id AND rp.point_type = 'dropping' AND rp.name = p.name
  );

-- Generic points for other active routes (origin/destination terminals)
INSERT INTO public.route_points (route_id, point_type, name, offset_minutes, sort_order)
SELECT r.id, 'boarding', COALESCE(r.origin_terminal, r.origin_city || ' Bus Stand'), 0, 1
FROM public.routes r
WHERE r.is_active
  AND NOT EXISTS (
      SELECT 1 FROM public.route_points rp
      WHERE rp.route_id = r.id AND rp.point_type = 'boarding'
  );

INSERT INTO public.route_points (route_id, point_type, name, offset_minutes, sort_order)
SELECT r.id, 'dropping', COALESCE(r.destination_terminal, r.destination_city || ' Bus Stand'), 0, 1
FROM public.routes r
WHERE r.is_active
  AND NOT EXISTS (
      SELECT 1 FROM public.route_points rp
      WHERE rp.route_id = r.id AND rp.point_type = 'dropping'
  );

-- Seed 2+2 seater layout for demo AC / Non-AC buses
DO $$
DECLARE
    b RECORD;
    r INT;
    seat_label TEXT;
    col INT;
    seq INT;
BEGIN
    FOR b IN
        SELECT id, bus_type, total_seats
        FROM public.buses
        WHERE registration_no IN ('WP NB-1001', 'WP NB-1002')
    LOOP
        IF EXISTS (SELECT 1 FROM public.seat_layouts WHERE bus_id = b.id) THEN
            CONTINUE;
        END IF;

        -- Driver placeholder
        INSERT INTO public.seat_layouts (bus_id, seat_number, row_index, column_index, seat_type, deck_level, is_available, reserved_for)
        VALUES (b.id, 'DRV', 0, 0, 'driver', 'lower', FALSE, 'any');

        seq := 1;
        FOR r IN 1..10 LOOP
            -- 2+2: cols 0,1 | aisle | 3,4
            FOR col IN 0..4 LOOP
                IF col = 2 THEN
                    INSERT INTO public.seat_layouts (bus_id, seat_number, row_index, column_index, seat_type, deck_level, is_available)
                    VALUES (b.id, 'A' || r::text, r, col, 'aisle', 'lower', FALSE);
                ELSE
                    seat_label := r::text || CASE col WHEN 0 THEN 'A' WHEN 1 THEN 'B' WHEN 3 THEN 'C' ELSE 'D' END;
                    INSERT INTO public.seat_layouts (bus_id, seat_number, row_index, column_index, seat_type, deck_level, is_available, reserved_for)
                    VALUES (
                        b.id,
                        seat_label,
                        r,
                        col,
                        'seater',
                        'lower',
                        TRUE,
                        CASE WHEN col IN (0, 1) AND r <= 2 THEN 'female' ELSE 'any' END
                    );
                    seq := seq + 1;
                    EXIT WHEN seq > b.total_seats;
                END IF;
            END LOOP;
            EXIT WHEN seq > b.total_seats;
        END LOOP;
    END LOOP;
END $$;

-- Seed sleeper lower/upper for WP NB-1003
DO $$
DECLARE
    v_bus UUID;
    r INT;
    side TEXT;
    col INT;
BEGIN
    SELECT id INTO v_bus FROM public.buses WHERE registration_no = 'WP NB-1003';
    IF v_bus IS NULL THEN
        RETURN;
    END IF;
    IF EXISTS (SELECT 1 FROM public.seat_layouts WHERE bus_id = v_bus) THEN
        RETURN;
    END IF;

    INSERT INTO public.seat_layouts (bus_id, seat_number, row_index, column_index, seat_type, deck_level, is_available)
    VALUES (v_bus, 'DRV', 0, 0, 'driver', 'lower', FALSE);

    FOR r IN 1..8 LOOP
        -- Lower deck: LzA (window) aisle LzB
        INSERT INTO public.seat_layouts (bus_id, seat_number, row_index, column_index, seat_type, deck_level, is_available, reserved_for)
        VALUES
            (v_bus, 'L' || r || 'A', r, 0, 'sleeper_lower', 'lower', TRUE, CASE WHEN r = 1 THEN 'female' ELSE 'any' END),
            (v_bus, 'AISLE-L' || r, r, 1, 'aisle', 'lower', FALSE, 'any'),
            (v_bus, 'L' || r || 'B', r, 2, 'sleeper_lower', 'lower', TRUE, 'any');

        -- Upper deck
        INSERT INTO public.seat_layouts (bus_id, seat_number, row_index, column_index, seat_type, deck_level, is_available, reserved_for)
        VALUES
            (v_bus, 'U' || r || 'A', r, 0, 'sleeper_upper', 'upper', TRUE, 'any'),
            (v_bus, 'AISLE-U' || r, r, 1, 'aisle', 'upper', FALSE, 'any'),
            (v_bus, 'U' || r || 'B', r, 2, 'sleeper_upper', 'upper', TRUE, 'any');
    END LOOP;
END $$;
