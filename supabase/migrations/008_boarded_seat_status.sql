-- =============================================================================
-- Add boarded seat status (must commit before functions use the value)
-- =============================================================================

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_enum e
        JOIN pg_type t ON t.oid = e.enumtypid
        WHERE t.typname = 'seat_booking_status' AND e.enumlabel = 'boarded'
    ) THEN
        ALTER TYPE seat_booking_status ADD VALUE 'boarded';
    END IF;
END $$;

ALTER TABLE public.booked_seats
    ADD COLUMN IF NOT EXISTS boarded_at TIMESTAMPTZ;
