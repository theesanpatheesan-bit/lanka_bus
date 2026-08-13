-- =============================================================================
-- Step 7: Passenger live tracking + Admin portal RPCs
-- Run AFTER 009_operator_conductor_apis.sql
-- =============================================================================

-- Realtime: bus_locations for passenger map
DO $$
BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.bus_locations;
EXCEPTION
    WHEN duplicate_object THEN NULL;
    WHEN undefined_object THEN NULL;
END $$;

-- Ticket JSON: expose bus_id + schedule_id for Track Live
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
        'bus_id', bus.id,
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
            WHERE bs.booking_id = b.id AND bs.status IN ('booked', 'boarded')
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

-- Snapshot used by passenger map (public-safe trip + last GPS)
CREATE OR REPLACE FUNCTION public.get_live_tracking_snapshot(
    p_schedule_id UUID DEFAULT NULL,
    p_bus_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_schedule_id UUID;
    v_bus_id UUID;
    v_result JSONB;
BEGIN
    IF p_schedule_id IS NULL AND p_bus_id IS NULL THEN
        RAISE EXCEPTION 'schedule_id or bus_id required';
    END IF;

    IF p_schedule_id IS NOT NULL THEN
        SELECT s.id, s.bus_id INTO v_schedule_id, v_bus_id
        FROM public.bus_schedules s
        WHERE s.id = p_schedule_id;
    ELSE
        SELECT s.id, s.bus_id INTO v_schedule_id, v_bus_id
        FROM public.bus_schedules s
        WHERE s.bus_id = p_bus_id
          AND s.status IN ('scheduled', 'boarding', 'departed')
          AND s.departure_at <= NOW() + INTERVAL '12 hours'
          AND s.arrival_at >= NOW() - INTERVAL '2 hours'
        ORDER BY s.departure_at DESC
        LIMIT 1;

        IF v_bus_id IS NULL THEN
            v_bus_id := p_bus_id;
        END IF;
    END IF;

    IF v_bus_id IS NULL THEN
        RAISE EXCEPTION 'Trip not found';
    END IF;

    SELECT jsonb_build_object(
        'schedule_id', s.id,
        'bus_id', bus.id,
        'status', s.status,
        'departure_at', s.departure_at,
        'arrival_at', s.arrival_at,
        'origin_city', r.origin_city,
        'destination_city', r.destination_city,
        'origin_terminal', r.origin_terminal,
        'destination_terminal', r.destination_terminal,
        'bus_number', bus.bus_number,
        'bus_registration', bus.registration_no,
        'operator_name', COALESCE(o.trade_name, o.company_name),
        'operator_phone', o.contact_phone,
        'conductor_phone', cu.phone,
        'distance_km', r.distance_km,
        'estimated_duration_minutes', r.estimated_duration_minutes,
        'latitude', loc.current_latitude,
        'longitude', loc.current_longitude,
        'speed_kmh', loc.speed_kmh,
        'heading_degrees', loc.heading_degrees,
        'location_updated_at', loc.updated_at,
        'is_online', (
            loc.updated_at IS NOT NULL
            AND loc.updated_at > NOW() - INTERVAL '3 minutes'
        ),
        'boarding_points', (
            SELECT COALESCE(jsonb_agg(
                jsonb_build_object(
                    'id', rp.id,
                    'name', rp.name,
                    'offset_minutes', rp.offset_minutes,
                    'sort_order', rp.sort_order
                )
                ORDER BY rp.sort_order, rp.offset_minutes
            ), '[]'::jsonb)
            FROM public.route_points rp
            WHERE rp.route_id = r.id
              AND rp.point_type = 'boarding'
              AND rp.is_active
        ),
        'dropping_points', (
            SELECT COALESCE(jsonb_agg(
                jsonb_build_object(
                    'id', rp.id,
                    'name', rp.name,
                    'offset_minutes', rp.offset_minutes,
                    'sort_order', rp.sort_order
                )
                ORDER BY rp.sort_order, rp.offset_minutes
            ), '[]'::jsonb)
            FROM public.route_points rp
            WHERE rp.route_id = r.id
              AND rp.point_type = 'dropping'
              AND rp.is_active
        )
    )
    INTO v_result
    FROM public.buses bus
    LEFT JOIN public.bus_schedules s ON s.id = v_schedule_id
    LEFT JOIN public.routes r ON r.id = s.route_id
    LEFT JOIN public.operators o ON o.id = COALESCE(s.operator_id, bus.operator_id)
    LEFT JOIN public.users cu ON cu.id = s.conductor_user_id
    LEFT JOIN public.bus_locations loc ON loc.bus_id = bus.id
    WHERE bus.id = v_bus_id;

    IF v_result IS NULL THEN
        RAISE EXCEPTION 'Bus not found';
    END IF;

    RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_live_tracking_snapshot TO anon, authenticated;

-- ---------- Admin analytics ----------
CREATE OR REPLACE FUNCTION public.admin_dashboard_metrics()
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_day_start TIMESTAMPTZ := date_trunc('day', NOW());
    v_day_end TIMESTAMPTZ := v_day_start + INTERVAL '1 day';
BEGIN
    IF NOT public.is_admin() THEN
        RAISE EXCEPTION 'Admin only';
    END IF;

    RETURN jsonb_build_object(
        'bookings_today', (
            SELECT COUNT(*)::int
            FROM public.bookings b
            WHERE b.created_at >= v_day_start
              AND b.created_at < v_day_end
              AND b.booking_status IN ('confirmed', 'completed')
        ),
        'revenue_today_lkr', (
            SELECT COALESCE(SUM(b.total_amount_lkr), 0)
            FROM public.bookings b
            WHERE b.created_at >= v_day_start
              AND b.created_at < v_day_end
              AND b.booking_status IN ('confirmed', 'completed')
              AND b.payment_status IN ('paid', 'pending')
        ),
        'active_buses', (
            SELECT COUNT(*)::int
            FROM public.bus_locations loc
            WHERE loc.updated_at > NOW() - INTERVAL '5 minutes'
        ),
        'commission_today_lkr', (
            SELECT COALESCE(SUM(b.total_amount_lkr * COALESCE(o.commission_rate, 0) / 100.0), 0)
            FROM public.bookings b
            JOIN public.bus_schedules s ON s.id = b.schedule_id
            JOIN public.operators o ON o.id = s.operator_id
            WHERE b.created_at >= v_day_start
              AND b.created_at < v_day_end
              AND b.booking_status IN ('confirmed', 'completed')
        ),
        'pending_operators', (
            SELECT COUNT(*)::int FROM public.operators WHERE status = 'pending'
        ),
        'active_operators', (
            SELECT COUNT(*)::int FROM public.operators WHERE status = 'active'
        )
    );
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_list_operators(p_status TEXT DEFAULT NULL)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF NOT public.is_admin() THEN
        RAISE EXCEPTION 'Admin only';
    END IF;

    RETURN COALESCE((
        SELECT jsonb_agg(row_to_json(t)::jsonb ORDER BY t.created_at DESC)
        FROM (
            SELECT
                o.id,
                o.company_name,
                o.trade_name,
                o.br_number,
                o.vat_number,
                o.contact_email,
                o.contact_phone,
                o.address_line1,
                o.city,
                o.status,
                o.commission_rate,
                o.rating,
                o.created_at,
                u.full_name AS owner_name,
                u.email AS owner_email
            FROM public.operators o
            LEFT JOIN public.users u ON u.id = o.owner_user_id
            WHERE (p_status IS NULL OR o.status::text = p_status)
        ) t
    ), '[]'::jsonb);
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_set_operator_status(
    p_operator_id UUID,
    p_status TEXT,
    p_note TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_row public.operators%ROWTYPE;
BEGIN
    IF NOT public.is_admin() THEN
        RAISE EXCEPTION 'Admin only';
    END IF;

    IF p_status NOT IN ('pending', 'active', 'suspended', 'rejected') THEN
        RAISE EXCEPTION 'Invalid status';
    END IF;

    UPDATE public.operators
    SET status = p_status::operator_status,
        updated_at = NOW()
    WHERE id = p_operator_id
    RETURNING * INTO v_row;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Operator not found';
    END IF;

    -- Activate owner as operator role when approved
    IF p_status = 'active' AND v_row.owner_user_id IS NOT NULL THEN
        UPDATE public.users
        SET role = 'operator',
            updated_at = NOW()
        WHERE id = v_row.owner_user_id
          AND role = 'passenger';
    END IF;

    RETURN jsonb_build_object(
        'id', v_row.id,
        'status', v_row.status,
        'note', p_note
    );
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_list_buses()
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF NOT public.is_admin() THEN
        RAISE EXCEPTION 'Admin only';
    END IF;

    RETURN COALESCE((
        SELECT jsonb_agg(row_to_json(t)::jsonb ORDER BY t.created_at DESC)
        FROM (
            SELECT
                b.id,
                b.operator_id,
                b.bus_number,
                b.registration_no,
                b.bus_type,
                b.total_seats,
                b.amenities,
                b.is_active,
                b.created_at,
                COALESCE(o.trade_name, o.company_name) AS operator_name,
                (
                    SELECT COUNT(*)::int
                    FROM public.seat_layouts sl
                    WHERE sl.bus_id = b.id
                      AND sl.seat_type IN ('seater', 'sleeper_lower', 'sleeper_upper')
                ) AS layout_seat_count
            FROM public.buses b
            JOIN public.operators o ON o.id = b.operator_id
        ) t
    ), '[]'::jsonb);
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_upsert_bus(
    p_operator_id UUID,
    p_bus_number TEXT,
    p_registration_no TEXT,
    p_bus_type TEXT,
    p_total_seats INT,
    p_amenities JSONB DEFAULT '[]'::JSONB,
    p_bus_id UUID DEFAULT NULL,
    p_generate_layout BOOLEAN DEFAULT TRUE
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_bus_id UUID;
    v_type bus_type;
    r INT;
    col INT;
    seq INT;
    seat_label TEXT;
    rows_needed INT;
BEGIN
    IF NOT public.is_admin() THEN
        RAISE EXCEPTION 'Admin only';
    END IF;

    v_type := p_bus_type::bus_type;

    IF p_bus_id IS NULL THEN
        INSERT INTO public.buses (
            operator_id, bus_number, registration_no, bus_type, total_seats, amenities
        ) VALUES (
            p_operator_id, p_bus_number, p_registration_no, v_type, p_total_seats,
            COALESCE(p_amenities, '[]'::JSONB)
        )
        RETURNING id INTO v_bus_id;
    ELSE
        UPDATE public.buses
        SET bus_number = p_bus_number,
            registration_no = p_registration_no,
            bus_type = v_type,
            total_seats = p_total_seats,
            amenities = COALESCE(p_amenities, amenities),
            updated_at = NOW()
        WHERE id = p_bus_id
        RETURNING id INTO v_bus_id;

        IF v_bus_id IS NULL THEN
            RAISE EXCEPTION 'Bus not found';
        END IF;
    END IF;

    IF p_generate_layout AND NOT EXISTS (
        SELECT 1 FROM public.seat_layouts WHERE bus_id = v_bus_id
    ) THEN
        INSERT INTO public.seat_layouts (
            bus_id, seat_number, row_index, column_index, seat_type, deck_level, is_available, reserved_for
        ) VALUES (v_bus_id, 'DRV', 0, 0, 'driver', 'lower', FALSE, 'any');

        rows_needed := GREATEST(CEIL(p_total_seats / 4.0)::INT, 1);
        seq := 1;
        FOR r IN 1..rows_needed LOOP
            FOR col IN 0..4 LOOP
                EXIT WHEN seq > p_total_seats AND col <> 2;
                IF col = 2 THEN
                    INSERT INTO public.seat_layouts (
                        bus_id, seat_number, row_index, column_index, seat_type, deck_level, is_available
                    ) VALUES (v_bus_id, 'A' || r::text, r, col, 'aisle', 'lower', FALSE);
                ELSE
                    seat_label := r::text || CASE col WHEN 0 THEN 'A' WHEN 1 THEN 'B' WHEN 3 THEN 'C' ELSE 'D' END;
                    INSERT INTO public.seat_layouts (
                        bus_id, seat_number, row_index, column_index, seat_type, deck_level, is_available, reserved_for
                    ) VALUES (
                        v_bus_id,
                        seat_label,
                        r,
                        col,
                        CASE WHEN v_type IN ('sleeper', 'semi_sleeper') THEN 'sleeper_lower'::seat_type ELSE 'seater'::seat_type END,
                        'lower',
                        TRUE,
                        'any'
                    );
                    seq := seq + 1;
                END IF;
            END LOOP;
        END LOOP;
    END IF;

    RETURN jsonb_build_object('id', v_bus_id, 'bus_number', p_bus_number);
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_list_routes()
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF NOT public.is_admin() THEN
        RAISE EXCEPTION 'Admin only';
    END IF;

    RETURN COALESCE((
        SELECT jsonb_agg(row_to_json(t)::jsonb ORDER BY t.origin_city, t.destination_city)
        FROM (
            SELECT
                r.id,
                r.origin_city,
                r.destination_city,
                r.origin_terminal,
                r.destination_terminal,
                r.distance_km,
                r.estimated_duration_minutes,
                r.is_active,
                r.created_at,
                (
                    SELECT COALESCE(jsonb_agg(
                        jsonb_build_object(
                            'id', rp.id,
                            'point_type', rp.point_type,
                            'name', rp.name,
                            'offset_minutes', rp.offset_minutes,
                            'sort_order', rp.sort_order
                        )
                        ORDER BY rp.point_type, rp.sort_order
                    ), '[]'::jsonb)
                    FROM public.route_points rp
                    WHERE rp.route_id = r.id AND rp.is_active
                ) AS points
            FROM public.routes r
        ) t
    ), '[]'::jsonb);
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_upsert_route(
    p_origin_city TEXT,
    p_destination_city TEXT,
    p_origin_terminal TEXT DEFAULT NULL,
    p_destination_terminal TEXT DEFAULT NULL,
    p_distance_km NUMERIC DEFAULT NULL,
    p_duration_minutes INT DEFAULT NULL,
    p_route_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_id UUID;
BEGIN
    IF NOT public.is_admin() THEN
        RAISE EXCEPTION 'Admin only';
    END IF;

    IF p_route_id IS NULL THEN
        INSERT INTO public.routes (
            origin_city, destination_city, origin_terminal, destination_terminal,
            distance_km, estimated_duration_minutes
        ) VALUES (
            p_origin_city, p_destination_city,
            COALESCE(p_origin_terminal, p_origin_city || ' Bus Stand'),
            COALESCE(p_destination_terminal, p_destination_city || ' Bus Stand'),
            p_distance_km, p_duration_minutes
        )
        RETURNING id INTO v_id;
    ELSE
        UPDATE public.routes
        SET origin_city = p_origin_city,
            destination_city = p_destination_city,
            origin_terminal = COALESCE(p_origin_terminal, origin_terminal),
            destination_terminal = COALESCE(p_destination_terminal, destination_terminal),
            distance_km = COALESCE(p_distance_km, distance_km),
            estimated_duration_minutes = COALESCE(p_duration_minutes, estimated_duration_minutes),
            updated_at = NOW()
        WHERE id = p_route_id
        RETURNING id INTO v_id;
    END IF;

    RETURN jsonb_build_object('id', v_id);
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_upsert_route_point(
    p_route_id UUID,
    p_point_type TEXT,
    p_name TEXT,
    p_offset_minutes INT DEFAULT 0,
    p_sort_order INT DEFAULT 0,
    p_point_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_id UUID;
BEGIN
    IF NOT public.is_admin() THEN
        RAISE EXCEPTION 'Admin only';
    END IF;

    IF p_point_type NOT IN ('boarding', 'dropping') THEN
        RAISE EXCEPTION 'Invalid point_type';
    END IF;

    IF p_point_id IS NULL THEN
        INSERT INTO public.route_points (
            route_id, point_type, name, offset_minutes, sort_order
        ) VALUES (
            p_route_id, p_point_type, p_name, p_offset_minutes, p_sort_order
        )
        RETURNING id INTO v_id;
    ELSE
        UPDATE public.route_points
        SET name = p_name,
            offset_minutes = p_offset_minutes,
            sort_order = p_sort_order,
            point_type = p_point_type
        WHERE id = p_point_id
        RETURNING id INTO v_id;
    END IF;

    RETURN jsonb_build_object('id', v_id);
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_create_schedule(
    p_route_id UUID,
    p_bus_id UUID,
    p_operator_id UUID,
    p_departure_at TIMESTAMPTZ,
    p_arrival_at TIMESTAMPTZ,
    p_base_price_lkr NUMERIC,
    p_recurring_days INT DEFAULT 1
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_ids UUID[] := '{}';
    v_id UUID;
    i INT;
    v_dep TIMESTAMPTZ;
    v_arr TIMESTAMPTZ;
    v_seats INT;
BEGIN
    IF NOT public.is_admin() THEN
        RAISE EXCEPTION 'Admin only';
    END IF;

    SELECT total_seats INTO v_seats FROM public.buses WHERE id = p_bus_id;
    IF v_seats IS NULL THEN
        RAISE EXCEPTION 'Bus not found';
    END IF;

    FOR i IN 0..(GREATEST(p_recurring_days, 1) - 1) LOOP
        v_dep := p_departure_at + (i || ' days')::INTERVAL;
        v_arr := p_arrival_at + (i || ' days')::INTERVAL;

        INSERT INTO public.bus_schedules (
            route_id, bus_id, operator_id, departure_at, arrival_at,
            base_price_lkr, available_seats, status
        ) VALUES (
            p_route_id, p_bus_id, p_operator_id, v_dep, v_arr,
            p_base_price_lkr, v_seats, 'scheduled'
        )
        RETURNING id INTO v_id;

        v_ids := array_append(v_ids, v_id);
    END LOOP;

    RETURN jsonb_build_object('schedule_ids', to_jsonb(v_ids), 'count', cardinality(v_ids));
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_dashboard_metrics TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_list_operators TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_set_operator_status TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_list_buses TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_upsert_bus TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_list_routes TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_upsert_route TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_upsert_route_point TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_create_schedule TO authenticated;
