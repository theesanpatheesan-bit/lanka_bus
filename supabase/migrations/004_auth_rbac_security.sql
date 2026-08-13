-- =============================================================================
-- Lanka Bus — Auth security: prevent self-service role escalation
-- =============================================================================

-- New self-registrations may only create passenger profiles (admins exempt).
DROP POLICY IF EXISTS users_insert_own ON public.users;
CREATE POLICY users_insert_own ON public.users
    FOR INSERT
    WITH CHECK (
        (id = auth.uid() AND role = 'passenger')
        OR public.is_admin()
    );

-- Block non-admins from changing their own role.
CREATE OR REPLACE FUNCTION public.prevent_role_escalation()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF NEW.role IS DISTINCT FROM OLD.role AND NOT public.is_admin() THEN
        RAISE EXCEPTION 'Role changes are not permitted for this account';
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_prevent_role_escalation ON public.users;
CREATE TRIGGER trg_prevent_role_escalation
    BEFORE UPDATE OF role ON public.users
    FOR EACH ROW
    EXECUTE FUNCTION public.prevent_role_escalation();
