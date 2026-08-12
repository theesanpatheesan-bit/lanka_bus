-- =============================================================================
-- Lanka Bus — Initial Schema (PostgreSQL / Supabase)
-- Bus Booking & Fleet Management Platform (Sri Lanka)
-- =============================================================================

-- Extensions
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- =============================================================================
-- ENUMS
-- =============================================================================

CREATE TYPE user_role AS ENUM ('passenger', 'operator', 'conductor', 'admin');

CREATE TYPE bus_type AS ENUM ('ac', 'non_ac', 'sleeper', 'semi_sleeper', 'luxury');

CREATE TYPE seat_type AS ENUM ('seater', 'sleeper_lower', 'sleeper_upper', 'aisle', 'driver');

CREATE TYPE deck_level AS ENUM ('lower', 'upper');

CREATE TYPE payment_status AS ENUM ('pending', 'paid', 'failed', 'refunded', 'partially_refunded');

CREATE TYPE booking_status AS ENUM ('pending', 'confirmed', 'cancelled', 'completed', 'no_show');

CREATE TYPE seat_booking_status AS ENUM ('reserved', 'locked', 'booked', 'cancelled');

CREATE TYPE operator_status AS ENUM ('pending', 'active', 'suspended', 'rejected');

CREATE TYPE schedule_status AS ENUM ('scheduled', 'boarding', 'departed', 'arrived', 'cancelled');

-- =============================================================================
-- USERS (profiles linked to auth.users)
-- =============================================================================

CREATE TABLE public.users (
    id              UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    full_name       TEXT NOT NULL,
    phone           TEXT,
    email           TEXT,
    nic             TEXT,                          -- Sri Lanka National Identity Card
    role            user_role NOT NULL DEFAULT 'passenger',
    avatar_url      TEXT,
    is_active       BOOLEAN NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT users_phone_format CHECK (
        phone IS NULL OR phone ~ '^\+94[0-9]{9}$|^0[0-9]{9}$'
    ),
    CONSTRAINT users_nic_unique UNIQUE (nic)
);

CREATE INDEX idx_users_role ON public.users(role);
CREATE INDEX idx_users_phone ON public.users(phone);
CREATE INDEX idx_users_email ON public.users(email);

-- =============================================================================
-- OPERATORS (bus companies)
-- =============================================================================

CREATE TABLE public.operators (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_user_id       UUID NOT NULL REFERENCES public.users(id) ON DELETE RESTRICT,
    company_name        TEXT NOT NULL,
    trade_name          TEXT,
    br_number           TEXT NOT NULL,             -- Business Registration (Sri Lanka)
    vat_number          TEXT,                     -- VAT / GST equivalent
    contact_person      TEXT NOT NULL,
    contact_phone       TEXT NOT NULL,
    contact_email       TEXT NOT NULL,
    address_line1       TEXT NOT NULL,
    address_line2       TEXT,
    city                TEXT NOT NULL,
    district            TEXT,                     -- Sri Lanka district
    postal_code         TEXT,
    logo_url            TEXT,
    status              operator_status NOT NULL DEFAULT 'pending',
    commission_rate     NUMERIC(5, 2) NOT NULL DEFAULT 5.00
                            CHECK (commission_rate >= 0 AND commission_rate <= 100),
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT operators_br_number_unique UNIQUE (br_number),
    CONSTRAINT operators_vat_number_unique UNIQUE (vat_number),
    CONSTRAINT operators_contact_email_format CHECK (
        contact_email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'
    )
);

CREATE INDEX idx_operators_status ON public.operators(status);
CREATE INDEX idx_operators_owner ON public.operators(owner_user_id);

-- =============================================================================
-- OPERATOR STAFF (conductors / operator staff mapped to an operator)
-- =============================================================================

CREATE TABLE public.operator_staff (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    operator_id     UUID NOT NULL REFERENCES public.operators(id) ON DELETE CASCADE,
    user_id         UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    staff_role      user_role NOT NULL CHECK (staff_role IN ('operator', 'conductor')),
    employee_code   TEXT,
    is_active       BOOLEAN NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT operator_staff_unique UNIQUE (operator_id, user_id)
);

CREATE INDEX idx_operator_staff_user ON public.operator_staff(user_id);

-- =============================================================================
-- BUSES
-- =============================================================================

CREATE TABLE public.buses (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    operator_id     UUID NOT NULL REFERENCES public.operators(id) ON DELETE CASCADE,
    bus_number      TEXT NOT NULL,                -- e.g. WP NB-1234
    registration_no TEXT NOT NULL,
    bus_type        bus_type NOT NULL DEFAULT 'non_ac',
    make_model      TEXT,
    manufacture_year SMALLINT CHECK (
        manufacture_year IS NULL
        OR (manufacture_year >= 1990 AND manufacture_year <= EXTRACT(YEAR FROM NOW())::SMALLINT + 1)
    ),
    total_seats     SMALLINT NOT NULL CHECK (total_seats > 0 AND total_seats <= 80),
    amenities       JSONB NOT NULL DEFAULT '[]'::JSONB,  -- ["wifi","usb","water","toilet"]
    is_active       BOOLEAN NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT buses_operator_bus_number_unique UNIQUE (operator_id, bus_number),
    CONSTRAINT buses_registration_unique UNIQUE (registration_no)
);

CREATE INDEX idx_buses_operator ON public.buses(operator_id);
CREATE INDEX idx_buses_type ON public.buses(bus_type);
CREATE INDEX idx_buses_amenities ON public.buses USING GIN (amenities);

-- =============================================================================
-- ROUTES
-- =============================================================================

CREATE TABLE public.routes (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    origin_city         TEXT NOT NULL,
    destination_city    TEXT NOT NULL,
    origin_terminal     TEXT,
    destination_terminal TEXT,
    distance_km         NUMERIC(8, 2) NOT NULL CHECK (distance_km > 0),
    estimated_duration_minutes INTEGER NOT NULL CHECK (estimated_duration_minutes > 0),
    is_active           BOOLEAN NOT NULL DEFAULT TRUE,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT routes_origin_destination_check CHECK (
        lower(origin_city) <> lower(destination_city)
    ),
    CONSTRAINT routes_unique_pair UNIQUE (origin_city, destination_city, origin_terminal, destination_terminal)
);

CREATE INDEX idx_routes_origin ON public.routes(origin_city);
CREATE INDEX idx_routes_destination ON public.routes(destination_city);
CREATE INDEX idx_routes_pair ON public.routes(origin_city, destination_city);

-- =============================================================================
-- SEAT LAYOUTS (template per bus — grid configuration)
-- =============================================================================

CREATE TABLE public.seat_layouts (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    bus_id          UUID NOT NULL REFERENCES public.buses(id) ON DELETE CASCADE,
    seat_number     TEXT NOT NULL,                -- e.g. "1A", "L1", "U3"
    row_index       SMALLINT NOT NULL CHECK (row_index >= 0),
    column_index    SMALLINT NOT NULL CHECK (column_index >= 0),
    seat_type       seat_type NOT NULL DEFAULT 'seater',
    deck_level      deck_level NOT NULL DEFAULT 'lower',
    is_available    BOOLEAN NOT NULL DEFAULT TRUE, -- false for aisle/driver placeholders
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT seat_layouts_bus_seat_unique UNIQUE (bus_id, seat_number),
    CONSTRAINT seat_layouts_bus_position_unique UNIQUE (bus_id, deck_level, row_index, column_index)
);

CREATE INDEX idx_seat_layouts_bus ON public.seat_layouts(bus_id);

-- =============================================================================
-- BUS SCHEDULES
-- =============================================================================

CREATE TABLE public.bus_schedules (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    route_id            UUID NOT NULL REFERENCES public.routes(id) ON DELETE RESTRICT,
    bus_id              UUID NOT NULL REFERENCES public.buses(id) ON DELETE RESTRICT,
    operator_id         UUID NOT NULL REFERENCES public.operators(id) ON DELETE RESTRICT,
    departure_at        TIMESTAMPTZ NOT NULL,
    arrival_at          TIMESTAMPTZ NOT NULL,
    base_price_lkr      NUMERIC(10, 2) NOT NULL CHECK (base_price_lkr >= 0),
    available_seats     SMALLINT NOT NULL CHECK (available_seats >= 0),
    status              schedule_status NOT NULL DEFAULT 'scheduled',
    conductor_user_id   UUID REFERENCES public.users(id) ON DELETE SET NULL,
    notes               TEXT,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT bus_schedules_time_order CHECK (arrival_at > departure_at)
);

CREATE INDEX idx_bus_schedules_route ON public.bus_schedules(route_id);
CREATE INDEX idx_bus_schedules_bus ON public.bus_schedules(bus_id);
CREATE INDEX idx_bus_schedules_operator ON public.bus_schedules(operator_id);
CREATE INDEX idx_bus_schedules_departure ON public.bus_schedules(departure_at);
CREATE INDEX idx_bus_schedules_search ON public.bus_schedules(route_id, departure_at, status);

-- Prevent same bus overlapping active schedules
CREATE INDEX idx_bus_schedules_bus_window ON public.bus_schedules(bus_id, departure_at, arrival_at)
    WHERE status <> 'cancelled';

-- =============================================================================
-- BOOKINGS
-- =============================================================================

CREATE TABLE public.bookings (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    booking_ref         TEXT NOT NULL,            -- e.g. LB-20260812-A1B2
    passenger_user_id   UUID NOT NULL REFERENCES public.users(id) ON DELETE RESTRICT,
    schedule_id         UUID NOT NULL REFERENCES public.bus_schedules(id) ON DELETE RESTRICT,
    passenger_name      TEXT NOT NULL,
    passenger_phone     TEXT NOT NULL,
    passenger_nic       TEXT,
    passenger_email     TEXT,
    seat_count          SMALLINT NOT NULL CHECK (seat_count > 0),
    total_amount_lkr    NUMERIC(12, 2) NOT NULL CHECK (total_amount_lkr >= 0),
    payment_status      payment_status NOT NULL DEFAULT 'pending',
    booking_status      booking_status NOT NULL DEFAULT 'pending',
    payment_method      TEXT,
    payment_reference   TEXT,
    booked_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    cancelled_at        TIMESTAMPTZ,
    cancellation_reason TEXT,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT bookings_ref_unique UNIQUE (booking_ref)
);

CREATE INDEX idx_bookings_passenger ON public.bookings(passenger_user_id);
CREATE INDEX idx_bookings_schedule ON public.bookings(schedule_id);
CREATE INDEX idx_bookings_status ON public.bookings(booking_status, payment_status);
CREATE INDEX idx_bookings_ref ON public.bookings(booking_ref);

-- =============================================================================
-- BOOKED SEATS
-- Prevents duplicate seat booking via partial unique index on active statuses
-- =============================================================================

CREATE TABLE public.booked_seats (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    booking_id      UUID NOT NULL REFERENCES public.bookings(id) ON DELETE CASCADE,
    schedule_id     UUID NOT NULL REFERENCES public.bus_schedules(id) ON DELETE CASCADE,
    seat_layout_id  UUID REFERENCES public.seat_layouts(id) ON DELETE SET NULL,
    seat_number     TEXT NOT NULL,
    passenger_name  TEXT,
    status          seat_booking_status NOT NULL DEFAULT 'locked',
    locked_until    TIMESTAMPTZ,                  -- soft-hold expiry for checkout
    fare_lkr        NUMERIC(10, 2) NOT NULL DEFAULT 0 CHECK (fare_lkr >= 0),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_booked_seats_booking ON public.booked_seats(booking_id);
CREATE INDEX idx_booked_seats_schedule ON public.booked_seats(schedule_id);
CREATE INDEX idx_booked_seats_status ON public.booked_seats(status);

-- CRITICAL: one active seat per schedule (no double-booking)
CREATE UNIQUE INDEX uq_booked_seats_active_seat
    ON public.booked_seats (schedule_id, seat_number)
    WHERE status IN ('reserved', 'locked', 'booked');

-- =============================================================================
-- BUS LOCATIONS (live GPS tracking)
-- =============================================================================

CREATE TABLE public.bus_locations (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    bus_id              UUID NOT NULL REFERENCES public.buses(id) ON DELETE CASCADE,
    schedule_id         UUID REFERENCES public.bus_schedules(id) ON DELETE SET NULL,
    current_latitude    DOUBLE PRECISION NOT NULL
                            CHECK (current_latitude BETWEEN -90 AND 90),
    current_longitude   DOUBLE PRECISION NOT NULL
                            CHECK (current_longitude BETWEEN -180 AND 180),
    speed_kmh           NUMERIC(6, 2),
    heading_degrees     NUMERIC(5, 2) CHECK (
        heading_degrees IS NULL OR (heading_degrees >= 0 AND heading_degrees < 360)
    ),
    accuracy_meters     NUMERIC(8, 2),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT bus_locations_bus_unique UNIQUE (bus_id)
);

CREATE INDEX idx_bus_locations_updated ON public.bus_locations(updated_at DESC);
CREATE INDEX idx_bus_locations_schedule ON public.bus_locations(schedule_id);

-- Optional history for analytics / playback
CREATE TABLE public.bus_location_history (
    id                  BIGSERIAL PRIMARY KEY,
    bus_id              UUID NOT NULL REFERENCES public.buses(id) ON DELETE CASCADE,
    schedule_id         UUID REFERENCES public.bus_schedules(id) ON DELETE SET NULL,
    latitude            DOUBLE PRECISION NOT NULL,
    longitude           DOUBLE PRECISION NOT NULL,
    speed_kmh           NUMERIC(6, 2),
    recorded_at         TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_bus_location_history_bus_time
    ON public.bus_location_history(bus_id, recorded_at DESC);

-- =============================================================================
-- HELPER: updated_at trigger
-- =============================================================================

CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_users_updated_at
    BEFORE UPDATE ON public.users
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER trg_operators_updated_at
    BEFORE UPDATE ON public.operators
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER trg_operator_staff_updated_at
    BEFORE UPDATE ON public.operator_staff
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER trg_buses_updated_at
    BEFORE UPDATE ON public.buses
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER trg_routes_updated_at
    BEFORE UPDATE ON public.routes
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER trg_bus_schedules_updated_at
    BEFORE UPDATE ON public.bus_schedules
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER trg_bookings_updated_at
    BEFORE UPDATE ON public.bookings
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER trg_booked_seats_updated_at
    BEFORE UPDATE ON public.booked_seats
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- =============================================================================
-- HELPER: auto-create profile on auth signup
-- =============================================================================

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    INSERT INTO public.users (id, full_name, email, phone, role)
    VALUES (
        NEW.id,
        COALESCE(NEW.raw_user_meta_data->>'full_name', split_part(NEW.email, '@', 1)),
        NEW.email,
        NEW.raw_user_meta_data->>'phone',
        COALESCE((NEW.raw_user_meta_data->>'role')::user_role, 'passenger')
    );
    RETURN NEW;
END;
$$;

CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- =============================================================================
-- HELPER: generate booking reference
-- =============================================================================

CREATE OR REPLACE FUNCTION public.generate_booking_ref()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.booking_ref IS NULL OR NEW.booking_ref = '' THEN
        NEW.booking_ref := 'LB-' || to_char(NOW() AT TIME ZONE 'Asia/Colombo', 'YYYYMMDD')
            || '-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 6));
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_bookings_ref
    BEFORE INSERT ON public.bookings
    FOR EACH ROW EXECUTE FUNCTION public.generate_booking_ref();

-- =============================================================================
-- HELPER: release expired seat locks
-- =============================================================================

CREATE OR REPLACE FUNCTION public.release_expired_seat_locks()
RETURNS INTEGER
LANGUAGE plpgsql
AS $$
DECLARE
    released_count INTEGER;
BEGIN
    UPDATE public.booked_seats
    SET status = 'cancelled',
        updated_at = NOW()
    WHERE status IN ('locked', 'reserved')
      AND locked_until IS NOT NULL
      AND locked_until < NOW();

    GET DIAGNOSTICS released_count = ROW_COUNT;
    RETURN released_count;
END;
$$;

-- =============================================================================
-- HELPER: sync available_seats on schedule after seat status changes
-- =============================================================================

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
      AND status IN ('reserved', 'locked', 'booked');

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

CREATE TRIGGER trg_sync_available_seats
    AFTER INSERT OR UPDATE OR DELETE ON public.booked_seats
    FOR EACH ROW EXECUTE FUNCTION public.sync_schedule_available_seats();
