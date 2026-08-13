-- =============================================================================
-- Fix auth signup profile trigger (empty phone / duplicate / role spoofing)
-- =============================================================================

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    INSERT INTO public.users (id, full_name, email, phone, role, is_active)
    VALUES (
        NEW.id,
        COALESCE(
            NULLIF(TRIM(NEW.raw_user_meta_data->>'full_name'), ''),
            NULLIF(split_part(COALESCE(NEW.email, ''), '@', 1), ''),
            'Passenger'
        ),
        NEW.email,
        NULLIF(TRIM(NEW.raw_user_meta_data->>'phone'), ''),
        'passenger', -- never trust client metadata for role
        TRUE
    )
    ON CONFLICT (id) DO UPDATE
    SET
        full_name = COALESCE(
            NULLIF(TRIM(EXCLUDED.full_name), ''),
            public.users.full_name
        ),
        email = COALESCE(EXCLUDED.email, public.users.email),
        phone = COALESCE(EXCLUDED.phone, public.users.phone),
        updated_at = NOW();

    RETURN NEW;
EXCEPTION
    WHEN check_violation THEN
        -- Retry without phone if format check fails
        INSERT INTO public.users (id, full_name, email, phone, role, is_active)
        VALUES (
            NEW.id,
            COALESCE(
                NULLIF(TRIM(NEW.raw_user_meta_data->>'full_name'), ''),
                NULLIF(split_part(COALESCE(NEW.email, ''), '@', 1), ''),
                'Passenger'
            ),
            NEW.email,
            NULL,
            'passenger',
            TRUE
        )
        ON CONFLICT (id) DO NOTHING;
        RETURN NEW;
END;
$$;
