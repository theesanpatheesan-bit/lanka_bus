-- =============================================================================
-- Lanka Bus — Operator ratings + demo fleet seed (for search testing)
-- =============================================================================

ALTER TABLE public.operators
    ADD COLUMN IF NOT EXISTS rating NUMERIC(2, 1) NOT NULL DEFAULT 4.5
        CHECK (rating >= 0 AND rating <= 5);

COMMENT ON COLUMN public.operators.rating IS 'Average passenger rating (0–5)';

-- Seed demo operator / buses / schedules when at least one auth user exists.
DO $$
DECLARE
    v_user_id UUID;
    v_operator_id UUID;
    v_bus_ac UUID;
    v_bus_non UUID;
    v_bus_sleep UUID;
    v_route_ck UUID;
    v_route_cg UUID;
    v_route_cj UUID;
    d DATE;
BEGIN
    SELECT id INTO v_user_id FROM auth.users ORDER BY created_at ASC LIMIT 1;
    IF v_user_id IS NULL THEN
        RAISE NOTICE '005_seed_demo_fleet: skipped — create an auth user first, then re-run.';
        RETURN;
    END IF;

    -- Ensure profile exists; never escalate role (keeps passenger accounts testable).
    INSERT INTO public.users (id, full_name, email, role)
    VALUES (
        v_user_id,
        COALESCE((SELECT raw_user_meta_data->>'full_name' FROM auth.users WHERE id = v_user_id), 'Demo Owner'),
        (SELECT email FROM auth.users WHERE id = v_user_id),
        'passenger'
    )
    ON CONFLICT (id) DO NOTHING;

    SELECT id INTO v_operator_id
    FROM public.operators
    WHERE br_number = 'BR-DEMO-LANKA-001'
    LIMIT 1;

    IF v_operator_id IS NULL THEN
        INSERT INTO public.operators (
            owner_user_id, company_name, trade_name, br_number, vat_number,
            contact_person, contact_phone, contact_email,
            address_line1, city, district, status, rating
        ) VALUES (
            v_user_id,
            'Super Line Travels',
            'Super Line',
            'BR-DEMO-LANKA-001',
            'VAT-DEMO-001',
            'Demo Manager',
            '+94771234567',
            'demo@superline.lk',
            'Bastian Mawatha',
            'Colombo',
            'Colombo',
            'active',
            4.6
        )
        RETURNING id INTO v_operator_id;
    ELSE
        UPDATE public.operators
        SET status = 'active', rating = COALESCE(rating, 4.6)
        WHERE id = v_operator_id;
    END IF;

    INSERT INTO public.operators (
        owner_user_id, company_name, trade_name, br_number,
        contact_person, contact_phone, contact_email,
        address_line1, city, status, rating
    ) VALUES (
        v_user_id,
        'Lanka Express',
        'LankaX',
        'BR-DEMO-LANKA-002',
        'Ops Lead',
        '+94771112233',
        'ops@lankaexpress.lk',
        'Pettah',
        'Colombo',
        'active',
        4.3
    )
    ON CONFLICT (br_number) DO NOTHING;

    -- Buses
    INSERT INTO public.buses (operator_id, bus_number, registration_no, bus_type, total_seats, amenities)
    SELECT v_operator_id, 'SL-AC-01', 'WP NB-1001', 'ac', 40, '["wifi","usb","water"]'::jsonb
    WHERE NOT EXISTS (SELECT 1 FROM public.buses WHERE registration_no = 'WP NB-1001')
    RETURNING id INTO v_bus_ac;

    INSERT INTO public.buses (operator_id, bus_number, registration_no, bus_type, total_seats, amenities)
    SELECT v_operator_id, 'SL-NA-02', 'WP NB-1002', 'non_ac', 49, '["usb"]'::jsonb
    WHERE NOT EXISTS (SELECT 1 FROM public.buses WHERE registration_no = 'WP NB-1002')
    RETURNING id INTO v_bus_non;

    INSERT INTO public.buses (operator_id, bus_number, registration_no, bus_type, total_seats, amenities)
    SELECT v_operator_id, 'SL-SL-03', 'WP NB-1003', 'sleeper', 30, '["wifi","blanket","water"]'::jsonb
    WHERE NOT EXISTS (SELECT 1 FROM public.buses WHERE registration_no = 'WP NB-1003')
    RETURNING id INTO v_bus_sleep;

    SELECT id INTO v_bus_ac FROM public.buses WHERE registration_no = 'WP NB-1001';
    SELECT id INTO v_bus_non FROM public.buses WHERE registration_no = 'WP NB-1002';
    SELECT id INTO v_bus_sleep FROM public.buses WHERE registration_no = 'WP NB-1003';

    SELECT id INTO v_route_ck FROM public.routes
    WHERE origin_city = 'Colombo' AND destination_city = 'Kandy' LIMIT 1;
    SELECT id INTO v_route_cg FROM public.routes
    WHERE origin_city = 'Colombo' AND destination_city = 'Galle' LIMIT 1;
    SELECT id INTO v_route_cj FROM public.routes
    WHERE origin_city = 'Colombo' AND destination_city = 'Jaffna' LIMIT 1;

    IF v_route_ck IS NULL OR v_bus_ac IS NULL THEN
        RAISE NOTICE '005_seed_demo_fleet: routes/buses missing — run 003_seed_routes first.';
        RETURN;
    END IF;

    -- Schedules for next 5 days (Colombo timezone mornings/afternoons/evenings)
    FOR d IN SELECT generate_series(CURRENT_DATE, CURRENT_DATE + 4, INTERVAL '1 day')::date LOOP
        -- Colombo → Kandy
        INSERT INTO public.bus_schedules (
            route_id, bus_id, operator_id, departure_at, arrival_at,
            base_price_lkr, available_seats, status
        )
        SELECT v_route_ck, v_bus_ac, v_operator_id,
               (d + TIME '06:30') AT TIME ZONE 'Asia/Colombo',
               (d + TIME '10:00') AT TIME ZONE 'Asia/Colombo',
               1850, 40, 'scheduled'
        WHERE NOT EXISTS (
            SELECT 1 FROM public.bus_schedules s
            WHERE s.bus_id = v_bus_ac
              AND s.departure_at = (d + TIME '06:30') AT TIME ZONE 'Asia/Colombo'
        );

        INSERT INTO public.bus_schedules (
            route_id, bus_id, operator_id, departure_at, arrival_at,
            base_price_lkr, available_seats, status
        )
        SELECT v_route_ck, v_bus_non, v_operator_id,
               (d + TIME '14:00') AT TIME ZONE 'Asia/Colombo',
               (d + TIME '17:30') AT TIME ZONE 'Asia/Colombo',
               1250, 49, 'scheduled'
        WHERE NOT EXISTS (
            SELECT 1 FROM public.bus_schedules s
            WHERE s.bus_id = v_bus_non
              AND s.departure_at = (d + TIME '14:00') AT TIME ZONE 'Asia/Colombo'
        );

        INSERT INTO public.bus_schedules (
            route_id, bus_id, operator_id, departure_at, arrival_at,
            base_price_lkr, available_seats, status
        )
        SELECT v_route_ck, v_bus_sleep, v_operator_id,
               (d + TIME '21:30') AT TIME ZONE 'Asia/Colombo',
               ((d + 1) + TIME '01:00') AT TIME ZONE 'Asia/Colombo',
               2500, 30, 'scheduled'
        WHERE NOT EXISTS (
            SELECT 1 FROM public.bus_schedules s
            WHERE s.bus_id = v_bus_sleep
              AND s.departure_at = (d + TIME '21:30') AT TIME ZONE 'Asia/Colombo'
        );

        -- Colombo → Galle
        IF v_route_cg IS NOT NULL THEN
            INSERT INTO public.bus_schedules (
                route_id, bus_id, operator_id, departure_at, arrival_at,
                base_price_lkr, available_seats, status
            )
            SELECT v_route_cg, v_bus_ac, v_operator_id,
                   (d + TIME '08:15') AT TIME ZONE 'Asia/Colombo',
                   (d + TIME '11:15') AT TIME ZONE 'Asia/Colombo',
                   1100, 40, 'scheduled'
            WHERE NOT EXISTS (
                SELECT 1 FROM public.bus_schedules s
                WHERE s.bus_id = v_bus_ac
                  AND s.departure_at = (d + TIME '08:15') AT TIME ZONE 'Asia/Colombo'
            );
        END IF;

        -- Colombo → Jaffna (night sleeper)
        IF v_route_cj IS NOT NULL THEN
            INSERT INTO public.bus_schedules (
                route_id, bus_id, operator_id, departure_at, arrival_at,
                base_price_lkr, available_seats, status
            )
            SELECT v_route_cj, v_bus_sleep, v_operator_id,
                   (d + TIME '20:00') AT TIME ZONE 'Asia/Colombo',
                   ((d + 1) + TIME '04:00') AT TIME ZONE 'Asia/Colombo',
                   3200, 30, 'scheduled'
            WHERE NOT EXISTS (
                SELECT 1 FROM public.bus_schedules s
                WHERE s.bus_id = v_bus_sleep
                  AND s.departure_at = (d + TIME '20:00') AT TIME ZONE 'Asia/Colombo'
            );
        END IF;
    END LOOP;

    RAISE NOTICE '005_seed_demo_fleet: demo schedules ready for Colombo routes.';
END $$;
