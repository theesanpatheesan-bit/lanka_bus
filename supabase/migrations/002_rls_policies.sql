-- =============================================================================
-- Lanka Bus — Row Level Security (RLS) Policies
-- =============================================================================

ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.operators ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.operator_staff ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.buses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.routes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.seat_layouts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bus_schedules ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bookings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.booked_seats ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bus_locations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bus_location_history ENABLE ROW LEVEL SECURITY;

-- Helper: current user role
CREATE OR REPLACE FUNCTION public.current_user_role()
RETURNS user_role
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT role FROM public.users WHERE id = auth.uid();
$$;

CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT EXISTS (
        SELECT 1 FROM public.users WHERE id = auth.uid() AND role = 'admin'
    );
$$;

CREATE OR REPLACE FUNCTION public.is_operator_member(p_operator_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT EXISTS (
        SELECT 1 FROM public.operators o
        WHERE o.id = p_operator_id AND o.owner_user_id = auth.uid()
    ) OR EXISTS (
        SELECT 1 FROM public.operator_staff s
        WHERE s.operator_id = p_operator_id
          AND s.user_id = auth.uid()
          AND s.is_active = TRUE
    );
$$;

-- ---------- users ----------
CREATE POLICY users_select_own_or_admin ON public.users
    FOR SELECT USING (id = auth.uid() OR public.is_admin());

CREATE POLICY users_update_own ON public.users
    FOR UPDATE USING (id = auth.uid() OR public.is_admin());

CREATE POLICY users_insert_own ON public.users
    FOR INSERT WITH CHECK (id = auth.uid() OR public.is_admin());

-- ---------- operators ----------
CREATE POLICY operators_public_read_active ON public.operators
    FOR SELECT USING (status = 'active' OR public.is_admin() OR owner_user_id = auth.uid());

CREATE POLICY operators_owner_insert ON public.operators
    FOR INSERT WITH CHECK (owner_user_id = auth.uid() OR public.is_admin());

CREATE POLICY operators_owner_update ON public.operators
    FOR UPDATE USING (owner_user_id = auth.uid() OR public.is_admin());

-- ---------- operator_staff ----------
CREATE POLICY operator_staff_member_read ON public.operator_staff
    FOR SELECT USING (
        user_id = auth.uid()
        OR public.is_operator_member(operator_id)
        OR public.is_admin()
    );

CREATE POLICY operator_staff_owner_manage ON public.operator_staff
    FOR ALL USING (public.is_operator_member(operator_id) OR public.is_admin());

-- ---------- buses ----------
CREATE POLICY buses_public_read_active ON public.buses
    FOR SELECT USING (is_active = TRUE OR public.is_operator_member(operator_id) OR public.is_admin());

CREATE POLICY buses_operator_manage ON public.buses
    FOR ALL USING (public.is_operator_member(operator_id) OR public.is_admin());

-- ---------- routes ----------
CREATE POLICY routes_public_read ON public.routes
    FOR SELECT USING (is_active = TRUE OR public.is_admin());

CREATE POLICY routes_admin_manage ON public.routes
    FOR ALL USING (public.is_admin());

-- ---------- seat_layouts ----------
CREATE POLICY seat_layouts_public_read ON public.seat_layouts
    FOR SELECT USING (TRUE);

CREATE POLICY seat_layouts_operator_manage ON public.seat_layouts
    FOR ALL USING (
        public.is_admin()
        OR EXISTS (
            SELECT 1 FROM public.buses b
            WHERE b.id = seat_layouts.bus_id
              AND public.is_operator_member(b.operator_id)
        )
    );

-- ---------- bus_schedules ----------
CREATE POLICY bus_schedules_public_read ON public.bus_schedules
    FOR SELECT USING (status <> 'cancelled' OR public.is_operator_member(operator_id) OR public.is_admin());

CREATE POLICY bus_schedules_operator_manage ON public.bus_schedules
    FOR ALL USING (public.is_operator_member(operator_id) OR public.is_admin());

-- ---------- bookings ----------
CREATE POLICY bookings_passenger_read ON public.bookings
    FOR SELECT USING (
        passenger_user_id = auth.uid()
        OR public.is_admin()
        OR EXISTS (
            SELECT 1 FROM public.bus_schedules s
            WHERE s.id = bookings.schedule_id
              AND public.is_operator_member(s.operator_id)
        )
    );

CREATE POLICY bookings_passenger_insert ON public.bookings
    FOR INSERT WITH CHECK (passenger_user_id = auth.uid());

CREATE POLICY bookings_passenger_update ON public.bookings
    FOR UPDATE USING (
        passenger_user_id = auth.uid()
        OR public.is_admin()
        OR EXISTS (
            SELECT 1 FROM public.bus_schedules s
            WHERE s.id = bookings.schedule_id
              AND public.is_operator_member(s.operator_id)
        )
    );

-- ---------- booked_seats ----------
CREATE POLICY booked_seats_read ON public.booked_seats
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.bookings b
            WHERE b.id = booked_seats.booking_id
              AND (
                  b.passenger_user_id = auth.uid()
                  OR public.is_admin()
                  OR EXISTS (
                      SELECT 1 FROM public.bus_schedules s
                      WHERE s.id = b.schedule_id
                        AND public.is_operator_member(s.operator_id)
                  )
              )
        )
        -- passengers need to see occupied seats for a schedule
        OR auth.role() = 'authenticated'
    );

CREATE POLICY booked_seats_insert ON public.booked_seats
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.bookings b
            WHERE b.id = booking_id AND b.passenger_user_id = auth.uid()
        )
        OR public.is_admin()
    );

CREATE POLICY booked_seats_update ON public.booked_seats
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM public.bookings b
            WHERE b.id = booked_seats.booking_id
              AND (
                  b.passenger_user_id = auth.uid()
                  OR public.is_admin()
                  OR EXISTS (
                      SELECT 1 FROM public.bus_schedules s
                      WHERE s.id = b.schedule_id
                        AND public.is_operator_member(s.operator_id)
                  )
              )
        )
    );

-- ---------- bus_locations ----------
CREATE POLICY bus_locations_public_read ON public.bus_locations
    FOR SELECT USING (TRUE);

CREATE POLICY bus_locations_staff_upsert ON public.bus_locations
    FOR ALL USING (
        public.is_admin()
        OR EXISTS (
            SELECT 1 FROM public.buses b
            WHERE b.id = bus_locations.bus_id
              AND public.is_operator_member(b.operator_id)
        )
    );

CREATE POLICY bus_location_history_read ON public.bus_location_history
    FOR SELECT USING (
        public.is_admin()
        OR EXISTS (
            SELECT 1 FROM public.buses b
            WHERE b.id = bus_location_history.bus_id
              AND public.is_operator_member(b.operator_id)
        )
    );

CREATE POLICY bus_location_history_insert ON public.bus_location_history
    FOR INSERT WITH CHECK (
        public.is_admin()
        OR EXISTS (
            SELECT 1 FROM public.buses b
            WHERE b.id = bus_id
              AND public.is_operator_member(b.operator_id)
        )
    );

-- Realtime publication for live tracking (Supabase)
-- Uncomment after enabling Realtime in dashboard if needed:
-- ALTER PUBLICATION supabase_realtime ADD TABLE public.bus_locations;
-- ALTER PUBLICATION supabase_realtime ADD TABLE public.booked_seats;
