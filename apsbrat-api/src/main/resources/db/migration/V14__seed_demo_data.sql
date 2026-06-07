-- ============================================================================
-- Demo seed: reproduces the data the Flutter UI previously hard-coded.
-- Current user is Arjun Singh (phone 919999000001). Log in with master OTP.
-- ============================================================================

-- 1) Ensure the three demo schools exist (idempotent by name) ----------------
INSERT INTO schools (id, name, city, state, is_active)
SELECT uuid_generate_v4(), 'APS Patiala', 'Patiala', 'Punjab', TRUE
WHERE NOT EXISTS (SELECT 1 FROM schools WHERE name = 'APS Patiala');

INSERT INTO schools (id, name, city, state, is_active)
SELECT uuid_generate_v4(), 'APS Pune', 'Pune', 'Maharashtra', TRUE
WHERE NOT EXISTS (SELECT 1 FROM schools WHERE name = 'APS Pune');

INSERT INTO schools (id, name, city, state, is_active)
SELECT uuid_generate_v4(), 'APS Delhi Cantt', 'New Delhi', 'Delhi', TRUE
WHERE NOT EXISTS (SELECT 1 FROM schools WHERE name = 'APS Delhi Cantt');

-- 2) Users -------------------------------------------------------------------
INSERT INTO users (id, username, full_name, phone, email, city, profession, current_status, gender, bio, is_verified, created_at, updated_at) VALUES
('11111111-1111-1111-1111-111111111111', 'arjun.singh',  'Arjun Singh',   '919999000001', 'arjun.singh@example.com',  'New Delhi', 'NDA Cadet',                 'ALUMNI',  'Male',   'NDA Cadet · Army brat through and through. APS Patiala → APS Pune → APS Delhi', TRUE, NOW() - INTERVAL '30 days', NOW() - INTERVAL '30 days'),
('22222222-2222-2222-2222-222222222222', 'priya.khanna',  'Priya Khanna',  '919999000002', 'priya.khanna@example.com', 'Bengaluru', 'Software Engineer, Wipro',  'ALUMNI',  'Female', NULL, TRUE, NOW(),                        NOW()),
('33333333-3333-3333-3333-333333333333', 'rohit.singh',   'Rohit Singh',   '919999000003', 'rohit.singh@example.com',  'Pune',      'NDA Cadet',                 'ALUMNI',  'Male',   NULL, TRUE, NOW(),                        NOW()),
('44444444-4444-4444-4444-444444444444', 'vikram.kumar',  'Vikram Kumar',  '919999000004', 'vikram.kumar@example.com', 'Hyderabad', 'BITS Pilani',               'STUDENT', 'Male',   NULL, TRUE, NOW(),                        NOW()),
('55555555-5555-5555-5555-555555555555', 'sneha.mehta',   'Sneha Mehta',   '919999000005', 'sneha.mehta@example.com',  'Mumbai',    'IIT Bombay',                'STUDENT', 'Female', NULL, TRUE, NOW() - INTERVAL '5 days',  NOW() - INTERVAL '5 days'),
('66666666-6666-6666-6666-666666666666', 'aakash.tiwari', 'Aakash Tiwari', '919999000006', 'aakash.tiwari@example.com','Delhi',     'DU Student',                'STUDENT', 'Male',   NULL, TRUE, NOW() - INTERVAL '5 days',  NOW() - INTERVAL '5 days'),
('77777777-7777-7777-7777-777777777777', 'meera.joshi',   'Meera Joshi',   '919999000007', 'meera.joshi@example.com',  'Chennai',   'Working at TCS',            'ALUMNI',  'Female', NULL, TRUE, NOW() - INTERVAL '5 days',  NOW() - INTERVAL '5 days'),
('88888888-8888-8888-8888-888888888888', 'karan.rao',     'Karan Rao',     '919999000008', 'karan.rao@example.com',    'Bengaluru', 'Infosys',                   'ALUMNI',  'Male',   NULL, TRUE, NOW() - INTERVAL '5 days',  NOW() - INTERVAL '5 days'),
('99999999-9999-9999-9999-999999999999', 'divya.nair',    'Divya Nair',    '919999000009', 'divya.nair@example.com',   'Kochi',     'NIT Calicut',               'STUDENT', 'Female', NULL, TRUE, NOW() - INTERVAL '5 days',  NOW() - INTERVAL '5 days'),
('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'amit.prasad',   'Amit Prasad',   '919999000010', 'amit.prasad@example.com',  'Jaipur',    'Army officer',              'ALUMNI',  'Male',   NULL, TRUE, NOW() - INTERVAL '5 days',  NOW() - INTERVAL '5 days'),
('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'riya.verma',    'Riya Verma',    '919999000011', 'riya.verma@example.com',   'Nagpur',    'MBBS, GMC Nagpur',          'STUDENT', 'Female', NULL, TRUE, NOW() - INTERVAL '5 days',  NOW() - INTERVAL '5 days');

-- 3) School history (section stores the grade+section label, e.g. 12A) -------
INSERT INTO user_school_history (id, user_id, school_id, class_from, class_to, section, batch_start, batch_end, is_primary) VALUES
-- Arjun: 3 schools
(uuid_generate_v4(), '11111111-1111-1111-1111-111111111111', (SELECT id FROM schools WHERE name='APS Patiala' ORDER BY created_at LIMIT 1),     11, 12, '12A', 2021, 2022, TRUE),
(uuid_generate_v4(), '11111111-1111-1111-1111-111111111111', (SELECT id FROM schools WHERE name='APS Pune' ORDER BY created_at LIMIT 1),         8,  9,  '9C',  2018, 2019, FALSE),
(uuid_generate_v4(), '11111111-1111-1111-1111-111111111111', (SELECT id FROM schools WHERE name='APS Delhi Cantt' ORDER BY created_at LIMIT 1),  1,  5,  'A',   2010, 2015, FALSE),
-- Others (single primary each)
(uuid_generate_v4(), '22222222-2222-2222-2222-222222222222', (SELECT id FROM schools WHERE name='APS Patiala' ORDER BY created_at LIMIT 1),     11, 12, '12A', 2021, 2022, TRUE),
(uuid_generate_v4(), '33333333-3333-3333-3333-333333333333', (SELECT id FROM schools WHERE name='APS Patiala' ORDER BY created_at LIMIT 1),     11, 12, '12A', 2021, 2022, TRUE),
(uuid_generate_v4(), '44444444-4444-4444-4444-444444444444', (SELECT id FROM schools WHERE name='APS Patiala' ORDER BY created_at LIMIT 1),     11, 12, '12A', 2021, 2022, TRUE),
(uuid_generate_v4(), '55555555-5555-5555-5555-555555555555', (SELECT id FROM schools WHERE name='APS Pune' ORDER BY created_at LIMIT 1),         8,  9,  '9C',  2018, 2019, TRUE),
(uuid_generate_v4(), '66666666-6666-6666-6666-666666666666', (SELECT id FROM schools WHERE name='APS Delhi Cantt' ORDER BY created_at LIMIT 1), 10, 11, '11B', 2020, 2021, TRUE),
(uuid_generate_v4(), '77777777-7777-7777-7777-777777777777', (SELECT id FROM schools WHERE name='APS Patiala' ORDER BY created_at LIMIT 1),     11, 12, '12A', 2021, 2022, TRUE),
(uuid_generate_v4(), '88888888-8888-8888-8888-888888888888', (SELECT id FROM schools WHERE name='APS Pune' ORDER BY created_at LIMIT 1),         8,  9,  '9C',  2018, 2019, TRUE),
(uuid_generate_v4(), '99999999-9999-9999-9999-999999999999', (SELECT id FROM schools WHERE name='APS Delhi Cantt' ORDER BY created_at LIMIT 1),  9, 10, '10A', 2019, 2020, TRUE),
(uuid_generate_v4(), 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', (SELECT id FROM schools WHERE name='APS Patiala' ORDER BY created_at LIMIT 1),     11, 12, '12B', 2021, 2022, TRUE),
(uuid_generate_v4(), 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', (SELECT id FROM schools WHERE name='APS Pune' ORDER BY created_at LIMIT 1),         7,  8,  '8A',  2017, 2018, TRUE);

-- 4) Communities -------------------------------------------------------------
INSERT INTO communities (id, name, badge, type, school_id, section, batch_start, batch_end, subtitle, auto_join_label, online_count, member_count_override, created_at) VALUES
('c1111111-1111-1111-1111-111111111111', '12A · APS Patiala · 2022', 'AUTO-JOINED', 'SECTION',   (SELECT id FROM schools WHERE name='APS Patiala' ORDER BY created_at LIMIT 1), '12A', 2021, 2022, NULL, 'AUTO-JOINED', 8, NULL, NOW()),
('c2222222-2222-2222-2222-222222222222', '9C · APS Pune · 2019',     'AUTO-JOINED', 'SECTION',   (SELECT id FROM schools WHERE name='APS Pune' ORDER BY created_at LIMIT 1),    '9C',  2018, 2019, NULL, 'AUTO-JOINED', 3, NULL, NOW()),
('c3333333-3333-3333-3333-333333333333', 'APS Delhi Cantt · 2010–2015', 'AUTO-JOINED', 'SCHOOL', (SELECT id FROM schools WHERE name='APS Delhi Cantt' ORDER BY created_at LIMIT 1), NULL, 2010, 2015, NULL, 'AUTO-JOINED', 1, NULL, NOW()),
('c4444444-4444-4444-4444-444444444444', 'APS Patiala — All years',  NULL,          'ALL_YEARS', (SELECT id FROM schools WHERE name='APS Patiala' ORDER BY created_at LIMIT 1), NULL, NULL, NULL, 'Everyone who attended', NULL, 0, 312, NOW()),
('c5555555-5555-5555-5555-555555555555', 'APS Brats — All India',    NULL,          'GLOBAL',    NULL, NULL, NULL, NULL, 'All 137 schools', NULL, 0, 4200, NOW());

-- 5) Community memberships (Arjun is in c1, c2, c3) --------------------------
-- c1 last_read_at NULL => shows unread; c2 NULL; c3 read.
INSERT INTO community_members (id, community_id, user_id, last_read_at, joined_at) VALUES
(uuid_generate_v4(), 'c1111111-1111-1111-1111-111111111111', '11111111-1111-1111-1111-111111111111', NULL,  NOW() - INTERVAL '20 days'),
(uuid_generate_v4(), 'c1111111-1111-1111-1111-111111111111', '22222222-2222-2222-2222-222222222222', NULL,  NOW()),
(uuid_generate_v4(), 'c1111111-1111-1111-1111-111111111111', '33333333-3333-3333-3333-333333333333', NULL,  NOW()),
(uuid_generate_v4(), 'c1111111-1111-1111-1111-111111111111', '44444444-4444-4444-4444-444444444444', NULL,  NOW()),
(uuid_generate_v4(), 'c1111111-1111-1111-1111-111111111111', '77777777-7777-7777-7777-777777777777', NULL,  NOW()),
(uuid_generate_v4(), 'c1111111-1111-1111-1111-111111111111', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', NULL,  NOW()),
(uuid_generate_v4(), 'c2222222-2222-2222-2222-222222222222', '11111111-1111-1111-1111-111111111111', NULL,  NOW() - INTERVAL '20 days'),
(uuid_generate_v4(), 'c2222222-2222-2222-2222-222222222222', '55555555-5555-5555-5555-555555555555', NULL,  NOW()),
(uuid_generate_v4(), 'c2222222-2222-2222-2222-222222222222', '88888888-8888-8888-8888-888888888888', NULL,  NOW()),
(uuid_generate_v4(), 'c2222222-2222-2222-2222-222222222222', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', NULL,  NOW()),
(uuid_generate_v4(), 'c3333333-3333-3333-3333-333333333333', '11111111-1111-1111-1111-111111111111', NOW(), NOW() - INTERVAL '20 days'),
(uuid_generate_v4(), 'c3333333-3333-3333-3333-333333333333', '66666666-6666-6666-6666-666666666666', NOW(), NOW()),
(uuid_generate_v4(), 'c3333333-3333-3333-3333-333333333333', '99999999-9999-9999-9999-999999999999', NOW(), NOW());

-- 6) Community messages (latest = preview) -----------------------------------
INSERT INTO community_messages (id, community_id, sender_id, body, created_at) VALUES
(uuid_generate_v4(), 'c1111111-1111-1111-1111-111111111111', '77777777-7777-7777-7777-777777777777', 'Reunion when?? 😄', NOW() - INTERVAL '20 minutes'),
(uuid_generate_v4(), 'c1111111-1111-1111-1111-111111111111', '33333333-3333-3333-3333-333333333333', 'guys remember PT period in Class 11? 🤣 those were the days', NOW() - INTERVAL '2 minutes'),
(uuid_generate_v4(), 'c2222222-2222-2222-2222-222222222222', '55555555-5555-5555-5555-555555555555', 'Pune cantt CSD canteen was the best 😍', NOW() - INTERVAL '1 hour'),
(uuid_generate_v4(), 'c3333333-3333-3333-3333-333333333333', '66666666-6666-6666-6666-666666666666', 'Anyone remember the annual sports day? 😄', NOW() - INTERVAL '1 day');

-- 7) Connections -------------------------------------------------------------
INSERT INTO connections (id, requester_id, addressee_id, status, created_at) VALUES
(uuid_generate_v4(), '33333333-3333-3333-3333-333333333333', '11111111-1111-1111-1111-111111111111', 'ACCEPTED', NOW() - INTERVAL '5 hours'),
(uuid_generate_v4(), '11111111-1111-1111-1111-111111111111', '55555555-5555-5555-5555-555555555555', 'ACCEPTED', NOW() - INTERVAL '3 days'),
(uuid_generate_v4(), '11111111-1111-1111-1111-111111111111', '88888888-8888-8888-8888-888888888888', 'ACCEPTED', NOW() - INTERVAL '4 days'),
(uuid_generate_v4(), '99999999-9999-9999-9999-999999999999', '11111111-1111-1111-1111-111111111111', 'ACCEPTED', NOW() - INTERVAL '6 days'),
(uuid_generate_v4(), '44444444-4444-4444-4444-444444444444', '11111111-1111-1111-1111-111111111111', 'PENDING',  NOW() - INTERVAL '1 hour');

-- 8) Feed events (activity feed) ---------------------------------------------
INSERT INTO feed_events (id, actor_id, type, title, body, meta, created_at) VALUES
(uuid_generate_v4(), '22222222-2222-2222-2222-222222222222', 'JOIN',      'Priya Khanna joined APS Brat',        'Priya is from your 12A batch at APS Patiala 2022. She''s now based in Bengaluru working at Wipro.', 'APS Patiala 12A', NOW() - INTERVAL '2 hours'),
(uuid_generate_v4(), '33333333-3333-3333-3333-333333333333', 'CONNECTED', 'Rohit Singh connected with you',      'Rohit accepted your connection request. You can now message each other on APS Brat.',               'APS Patiala 12A', NOW() - INTERVAL '5 hours'),
(uuid_generate_v4(), '55555555-5555-5555-5555-555555555555', 'JOIN',      'Sneha Mehta from 9C Pune joined',     'Sneha is from your 9C batch at APS Pune 2019. She''s currently in Mumbai at IIT Bombay.',            'APS Pune 9C',     NOW() - INTERVAL '1 day');

-- 9) Direct-message conversations + messages ---------------------------------
INSERT INTO conversations (id, user_a_id, user_b_id, last_message_at, created_at) VALUES
('d1111111-1111-1111-1111-111111111111', '11111111-1111-1111-1111-111111111111', '22222222-2222-2222-2222-222222222222', NOW() - INTERVAL '1 hour',   NOW() - INTERVAL '2 days'),
('d2222222-2222-2222-2222-222222222222', '11111111-1111-1111-1111-111111111111', '33333333-3333-3333-3333-333333333333', NOW() - INTERVAL '2 minutes',NOW() - INTERVAL '2 days'),
('d3333333-3333-3333-3333-333333333333', '11111111-1111-1111-1111-111111111111', '44444444-4444-4444-4444-444444444444', NOW() - INTERVAL '1 day',    NOW() - INTERVAL '3 days'),
('d4444444-4444-4444-4444-444444444444', '11111111-1111-1111-1111-111111111111', '55555555-5555-5555-5555-555555555555', NOW() - INTERVAL '2 days',   NOW() - INTERVAL '4 days'),
('d5555555-5555-5555-5555-555555555555', '11111111-1111-1111-1111-111111111111', '88888888-8888-8888-8888-888888888888', NOW() - INTERVAL '3 days',   NOW() - INTERVAL '5 days');

-- Priya conversation (read) — mirrors the demo chat history
INSERT INTO chat_messages (id, conversation_id, sender_id, body, read_at, created_at) VALUES
(uuid_generate_v4(), 'd1111111-1111-1111-1111-111111111111', '22222222-2222-2222-2222-222222222222', 'Arjun! Oh my god, I can''t believe you''re on here too! 😭', NOW(), NOW() - INTERVAL '90 minutes'),
(uuid_generate_v4(), 'd1111111-1111-1111-1111-111111111111', '11111111-1111-1111-1111-111111111111', 'Priya!! It''s been 3 years yaar 😭 How are you? Where are you now?', NOW(), NOW() - INTERVAL '85 minutes'),
(uuid_generate_v4(), 'd1111111-1111-1111-1111-111111111111', '22222222-2222-2222-2222-222222222222', 'In Bengaluru now! Working at Wipro. You??', NOW(), NOW() - INTERVAL '80 minutes'),
(uuid_generate_v4(), 'd1111111-1111-1111-1111-111111111111', '11111111-1111-1111-1111-111111111111', 'NDA Dehradun! Can you believe it 😅 Remember PT period in Class 11?', NOW(), NOW() - INTERVAL '70 minutes'),
(uuid_generate_v4(), 'd1111111-1111-1111-1111-111111111111', '22222222-2222-2222-2222-222222222222', 'HAHAHA yes!! Sir used to make us run 5 rounds if anyone talked 😂', NOW(), NOW() - INTERVAL '60 minutes');

-- Rohit conversation (3 unread from Rohit)
INSERT INTO chat_messages (id, conversation_id, sender_id, body, read_at, created_at) VALUES
(uuid_generate_v4(), 'd2222222-2222-2222-2222-222222222222', '33333333-3333-3333-3333-333333333333', 'Bro you saw the group?', NULL, NOW() - INTERVAL '10 minutes'),
(uuid_generate_v4(), 'd2222222-2222-2222-2222-222222222222', '33333333-3333-3333-3333-333333333333', 'So many people from our batch here', NULL, NOW() - INTERVAL '6 minutes'),
(uuid_generate_v4(), 'd2222222-2222-2222-2222-222222222222', '33333333-3333-3333-3333-333333333333', 'Yaar remember the canteen?? 😭', NULL, NOW() - INTERVAL '2 minutes');

-- Vikram conversation (1 unread)
INSERT INTO chat_messages (id, conversation_id, sender_id, body, read_at, created_at) VALUES
(uuid_generate_v4(), 'd3333333-3333-3333-3333-333333333333', '44444444-4444-4444-4444-444444444444', 'Bhai this app is insane 🔥', NULL, NOW() - INTERVAL '1 day');

-- Sneha conversation (read)
INSERT INTO chat_messages (id, conversation_id, sender_id, body, read_at, created_at) VALUES
(uuid_generate_v4(), 'd4444444-4444-4444-4444-444444444444', '55555555-5555-5555-5555-555555555555', 'Do you remember Mam from science?', NOW(), NOW() - INTERVAL '2 days');

-- Karan conversation (read)
INSERT INTO chat_messages (id, conversation_id, sender_id, body, read_at, created_at) VALUES
(uuid_generate_v4(), 'd5555555-5555-5555-5555-555555555555', '88888888-8888-8888-8888-888888888888', 'Pune cantt gang 🫡', NOW(), NOW() - INTERVAL '3 days');

-- 10) Notifications for Arjun ------------------------------------------------
INSERT INTO notifications (id, user_id, type, title, body, is_read, created_at) VALUES
(uuid_generate_v4(), '11111111-1111-1111-1111-111111111111', 'CONNECTION_REQUEST',  'Vikram Kumar wants to connect',          'You have a new connection request on APS Brat.', FALSE, NOW() - INTERVAL '1 hour'),
(uuid_generate_v4(), '11111111-1111-1111-1111-111111111111', 'CONNECTION_ACCEPTED', 'Rohit Singh accepted your request',      'You can now message each other on APS Brat.',    FALSE, NOW() - INTERVAL '5 hours'),
(uuid_generate_v4(), '11111111-1111-1111-1111-111111111111', 'JOIN',                'Priya Khanna joined APS Brat',           'Someone from your 12A batch just joined.',       TRUE,  NOW() - INTERVAL '2 hours'),
(uuid_generate_v4(), '11111111-1111-1111-1111-111111111111', 'MESSAGE',             'New message from Rohit Singh',           'Yaar remember the canteen?? 😭',                 FALSE, NOW() - INTERVAL '2 minutes');
