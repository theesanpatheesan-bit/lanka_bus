# Lanka Bus

Bus Booking & Fleet Management Platform for Sri Lanka (Flutter + Supabase).

## Steps 1–7

- Auth/RBAC, search, seats, payments/M-Ticket
- Operator seat chart, QR boarding, live GPS broadcast
- Passenger live map tracking + Admin web portal (fleet/routes/approvals)

## Setup

1. Run SQL migrations `001` … `010` in Supabase (`008`→`009`→`010`).
2. Enable Realtime for `bus_locations` (migration 010 tries to add it).
3. Enable Email (+ Phone if needed) in Auth providers.
4. Set `.env` with Supabase URL/anon key.
5. Set Google Maps API key in:
   - `android/app/src/main/AndroidManifest.xml` (`com.google.android.geo.API_KEY`)
   - `ios/Runner/AppDelegate.swift` (`GMSServices.provideAPIKey`)
6. `flutter pub get` → `flutter run` (or `flutter run -d chrome` for admin web)

### Promote admin

```sql
UPDATE public.users SET role = 'admin' WHERE email = 'you@example.com';
```

### Operator access for demo fleet

```sql
UPDATE public.users SET role = 'operator' WHERE email = 'you@example.com';

UPDATE public.operators
SET owner_user_id = (SELECT id FROM public.users WHERE email = 'you@example.com')
WHERE br_number = 'BR-DEMO-LANKA-001';
```

### Test Step 7

1. Operator starts trip GPS → passenger opens M-Ticket → **Track live bus**.
2. Share link: `lankabus://live-tracking?scheduleId=<uuid>`.
3. Admin dashboard → Overview / Fleet / Routes / Operator Onboarding.
