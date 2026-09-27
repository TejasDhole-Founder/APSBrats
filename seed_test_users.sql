-- ============================================================================
-- Test data: 100 users spread across ALL schools in the schools table.
--   * 1–3 schools each (about a third of users have 2 or 3 → multi-school profiles)
--   * realistic classes/batches per school (latest school = Class 10–12)
--   * 1–3 social links each
--   * all phone-verified, login with any of them via the dev master OTP 000000
-- Re-runnable: previously seeded users (username 'seed.*') are removed first;
-- their school history and socials go with them (ON DELETE CASCADE).
-- Run AFTER seed_schools.sql so people are spread over the real school list.
-- ============================================================================

DELETE FROM users WHERE username LIKE 'seed.%';

-- 1) Users -------------------------------------------------------------------
WITH cfg AS (
  SELECT
    ARRAY['Aarav','Vivaan','Aditya','Vihaan','Arjun','Sai','Reyansh','Krishna','Ishaan','Rohan',
          'Kabir','Ananya','Diya','Aadhya','Myra','Sara','Ira','Anika','Navya','Kiara',
          'Rahul','Priya','Neha','Karan','Pooja','Amit','Sneha','Vikram','Meera','Riya',
          'Tanvi','Yash','Dev','Nikhil','Shreya','Simran','Manish','Gaurav','Ritika','Harsh']::text[] AS fns,
    ARRAY['Sharma','Verma','Singh','Kumar','Mehta','Gupta','Nair','Rao','Reddy','Iyer',
          'Joshi','Chauhan','Malhotra','Kapoor','Bhatt','Das','Patel','Yadav','Mishra','Pillai',
          'Tiwari','Saxena','Bose','Sethi','Khanna']::text[] AS lns,
    ARRAY['Pune','Bengaluru','New Delhi','Mumbai','Hyderabad','Chennai','Kolkata','Jaipur',
          'Lucknow','Chandigarh','Dehradun','Kochi','Nagpur','Indore','Ahmedabad','Gurugram']::text[] AS cities,
    ARRAY['NDA Cadet','Software Engineer, Infosys','Doctor, AIIMS','IIT Bombay','Army Officer',
          'Chartered Accountant','Product Manager, Zomato','DU Student','Lawyer','Pilot, IndiGo',
          'Marketing, HUL','Data Scientist, TCS','MBBS Student','Civil Services Aspirant',
          'Architect','Merchant Navy']::text[] AS profs
),
gen AS (
  SELECT g,
         cfg.fns[1 + (g * 7)  % array_length(cfg.fns, 1)]    AS fn,
         cfg.lns[1 + (g * 11) % array_length(cfg.lns, 1)]    AS ln,
         cfg.cities[1 + (g * 5) % array_length(cfg.cities, 1)] AS city,
         cfg.profs[1 + (g * 3) % array_length(cfg.profs, 1)]  AS prof
  FROM cfg, generate_series(1, 100) AS g
)
INSERT INTO users (id, username, full_name, phone, email, city, profession, current_status,
                   gender, bio, is_verified, created_at, updated_at)
SELECT uuid_generate_v4(),
       'seed.' || lower(fn) || '.' || lower(ln) || '.' || g,
       fn || ' ' || ln,
       '9170000' || lpad(g::text, 4, '0'),
       'seed.' || lower(fn) || lower(ln) || g || '@example.com',
       city,
       prof,
       (CASE WHEN g % 3 = 0 THEN 'STUDENT' ELSE 'ALUMNI' END)::user_status,
       CASE WHEN g % 2 = 0 THEN 'Female' ELSE 'Male' END,
       NULL,
       TRUE,
       NOW() - (g || ' hours')::interval,
       NOW()
FROM gen;

-- 2) School history: 1–3 schools per user, newest school = Class 10–12 -------
WITH su AS (
  SELECT id, (regexp_match(username, '\.(\d+)$'))[1]::int AS g
  FROM users WHERE username LIKE 'seed.%'
),
sc AS (
  SELECT id, row_number() OVER (ORDER BY name) AS rn, count(*) OVER () AS n
  FROM schools
),
plan AS (
  SELECT su.id AS user_id, su.g, j, 2005 + (su.g % 20) AS y
  FROM su, generate_series(0, 2) AS j
  WHERE j < 1 + (su.g % 3)
)
INSERT INTO user_school_history (id, user_id, school_id, class_from, class_to, section,
                                 batch_start, batch_end, is_primary, stream)
SELECT uuid_generate_v4(),
       p.user_id,
       (SELECT sc.id FROM sc WHERE sc.rn = 1 + ((p.g * 13 + p.j * 17) % sc.n)),
       CASE p.j WHEN 0 THEN 10 WHEN 1 THEN 6 ELSE 1 END,
       CASE p.j WHEN 0 THEN 12 WHEN 1 THEN 9 ELSE 5 END,
       chr(65 + p.g % 4),  -- section letter only (class number is a separate column)
       CASE p.j WHEN 0 THEN p.y - 2 WHEN 1 THEN p.y - 6 ELSE p.y - 11 END,
       CASE p.j WHEN 0 THEN p.y     WHEN 1 THEN p.y - 3 ELSE p.y - 7  END,
       p.j = 0,
       -- Class 10-12 entries get a stream, spread across the five options.
       CASE WHEN p.j = 0 THEN (ARRAY['SCIENCE_MEDICAL','SCIENCE_NON_MEDICAL','SCIENCE_PCMB','COMMERCE','ARTS'])[1 + p.g % 5] END
FROM plan p;

-- 3) Social links: 1–3 per user ----------------------------------------------
WITH su AS (
  SELECT id, username, phone, (regexp_match(username, '\.(\d+)$'))[1]::int AS g
  FROM users WHERE username LIKE 'seed.%'
),
plat AS (SELECT ARRAY['INSTAGRAM','LINKEDIN','WHATSAPP','TWITTER']::text[] AS p)
INSERT INTO user_social_links (id, user_id, platform, handle, label, is_visible, created_at)
SELECT uuid_generate_v4(),
       su.id,
       (plat.p[1 + (su.g + j) % 4])::social_platform,
       CASE plat.p[1 + (su.g + j) % 4]
         WHEN 'WHATSAPP' THEN '+' || su.phone
         WHEN 'LINKEDIN' THEN 'linkedin.com/in/' || replace(substring(su.username FROM 6), '.', '-')
         ELSE '@' || replace(substring(su.username FROM 6), '.', '_')
       END,
       NULL,
       TRUE,
       NOW()
FROM su, plat, generate_series(0, 2) AS j
WHERE j < 1 + (su.g % 3);

-- 4) Connections so mutual batchmates show up ---------------------------------
-- Demo user Arjun (1111) is connected to Rohit (3333), 5555, 8888, 9999.
-- Connect those four among themselves and to the first ten seed users, so
-- opening any of their profiles shows "N mutual batchmates". Re-runnable.
WITH hub AS (
    SELECT unnest(ARRAY[
        '33333333-3333-3333-3333-333333333333',
        '55555555-5555-5555-5555-555555555555',
        '88888888-8888-8888-8888-888888888888',
        '99999999-9999-9999-9999-999999999999'
    ]::uuid[]) AS id
),
seeds AS (
    SELECT id FROM users WHERE username LIKE 'seed.%' ORDER BY username LIMIT 10
),
pairs AS (
    SELECT a.id AS x, b.id AS y FROM hub a JOIN hub b ON a.id < b.id
    UNION
    SELECT h.id, s.id FROM hub h JOIN seeds s ON true
    UNION
    SELECT '11111111-1111-1111-1111-111111111111'::uuid, s.id FROM seeds s
)
INSERT INTO connections (id, requester_id, addressee_id, status, created_at)
SELECT uuid_generate_v4(), p.x, p.y, 'ACCEPTED', NOW() - (random() * 60 || ' days')::interval
FROM pairs p
WHERE NOT EXISTS (
    SELECT 1 FROM connections c
    WHERE (c.requester_id = p.x AND c.addressee_id = p.y)
       OR (c.requester_id = p.y AND c.addressee_id = p.x)
);
