-- =============================================================================
-- Lanka Bus — Seed: common Sri Lankan city routes (optional)
-- =============================================================================

INSERT INTO public.routes (origin_city, destination_city, origin_terminal, destination_terminal, distance_km, estimated_duration_minutes)
VALUES
    ('Colombo', 'Kandy', 'Bastian Mawatha', 'Kandy Clock Tower', 115.00, 210),
    ('Colombo', 'Galle', 'Bastian Mawatha', 'Galle Bus Stand', 126.00, 180),
    ('Colombo', 'Jaffna', 'Bastian Mawatha', 'Jaffna Bus Stand', 396.00, 480),
    ('Colombo', 'Matara', 'Bastian Mawatha', 'Matara Bus Stand', 160.00, 240),
    ('Colombo', 'Anuradhapura', 'Bastian Mawatha', 'Anuradhapura New Bus Stand', 206.00, 300),
    ('Colombo', 'Trincomalee', 'Bastian Mawatha', 'Trincomalee Bus Stand', 266.00, 360),
    ('Kandy', 'Nuwara Eliya', 'Kandy Clock Tower', 'Nuwara Eliya Bus Stand', 77.00, 150),
    ('Colombo', 'Negombo', 'Bastian Mawatha', 'Negombo Bus Stand', 37.00, 75),
    ('Galle', 'Matara', 'Galle Bus Stand', 'Matara Bus Stand', 45.00, 60),
    ('Colombo', 'Kurunegala', 'Bastian Mawatha', 'Kurunegala Bus Stand', 94.00, 150)
ON CONFLICT DO NOTHING;
