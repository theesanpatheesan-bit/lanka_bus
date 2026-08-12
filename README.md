# Lanka Bus

Bus Booking & Fleet Management Platform for Sri Lanka (Flutter + Supabase).

## Step 1 deliverables

- PostgreSQL / Supabase schema: `supabase/migrations/`
- Feature-first Clean Architecture under `lib/`
- Supabase client bootstrap in `lib/main.dart` + `lib/core/network/supabase_client.dart`

## Setup

1. Create a Supabase project.
2. In the SQL Editor, run in order:
   - `supabase/migrations/001_initial_schema.sql`
   - `supabase/migrations/002_rls_policies.sql`
   - `supabase/migrations/003_seed_routes.sql` (optional)
3. Copy `.env.example` → `.env` and set `SUPABASE_URL` / `SUPABASE_ANON_KEY`.
4. `flutter pub get`
5. `flutter run`

## Architecture

```
lib/
  core/           # constants, network, theme, utils, errors
  features/
    auth/
    bus_search/
    seat_booking/
    tracking/
    operator_dashboard/
```

Each feature uses `data / domain / presentation` layers.
