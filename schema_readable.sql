-- ===================================================================
-- schema_readable.sql
-- Повна структура бази "festival_db" (тільки DDL: PK, FK, UNIQUE, CHECK, INDEX)
-- Без тригерів і без seed-даних
-- ===================================================================

-- Налаштування сесії
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;

-- =========================
-- 1) Послідовності (для SERIAL-like полів)
-- =========================
CREATE SEQUENCE IF NOT EXISTS public.artist_id_seq START 1 OWNED BY public.artist.id;
CREATE SEQUENCE IF NOT EXISTS public.person_id_seq START 1 OWNED BY public.person.id;
CREATE SEQUENCE IF NOT EXISTS public.organizer_id_seq START 1 OWNED BY public.organizer.id;
CREATE SEQUENCE IF NOT EXISTS public.equipment_provider_id_seq START 1 OWNED BY public.equipment_provider.id;
CREATE SEQUENCE IF NOT EXISTS public.venue_id_seq START 1 OWNED BY public.venue.id;
CREATE SEQUENCE IF NOT EXISTS public.event_id_seq START 1 OWNED BY public.event.id;
CREATE SEQUENCE IF NOT EXISTS public.festival_id_seq START 1 OWNED BY public.festival.id;

-- =========================
-- 2) Основні таблиці
-- =========================

-- ARTIST (узагальнення для solo | band)
CREATE TABLE IF NOT EXISTS public.artist (
    id bigint PRIMARY KEY DEFAULT nextval('public.artist_id_seq'),
    display_name text NOT NULL,
    country text,
    artist_type text NOT NULL CHECK (artist_type IN ('solo','band')),
    created_at timestamptz DEFAULT now()
);

-- Підтип solo_artist (ISA)
CREATE TABLE IF NOT EXISTS public.solo_artist (
    artist_id bigint PRIMARY KEY,
    real_name text NOT NULL,
    birth_date date,
    CONSTRAINT solo_artist_fk_artist FOREIGN KEY (artist_id) REFERENCES public.artist(id) ON DELETE CASCADE
);

-- Підтип band (ISA)
CREATE TABLE IF NOT EXISTS public.band (
    artist_id bigint PRIMARY KEY,
    formed_year int CHECK (formed_year IS NULL OR (formed_year BETWEEN 1900 AND EXTRACT(YEAR FROM now())::int)),
    genre text,
    CONSTRAINT band_fk_artist FOREIGN KEY (artist_id) REFERENCES public.artist(id) ON DELETE CASCADE
);

-- PERSON (директори, координатори, волонтери тощо)
CREATE TABLE IF NOT EXISTS public.person (
    id bigint PRIMARY KEY DEFAULT nextval('public.person_id_seq'),
    full_name text NOT NULL,
    email text,
    phone text,
    role text,
    created_at timestamptz DEFAULT now()
);

-- ORGANIZER
CREATE TABLE IF NOT EXISTS public.organizer (
    id bigint PRIMARY KEY DEFAULT nextval('public.organizer_id_seq'),
    org_name text NOT NULL,
    contact_email text,
    contact_phone text,
    address text,
    created_at timestamptz DEFAULT now()
);

-- EQUIPMENT_PROVIDER
CREATE TABLE IF NOT EXISTS public.equipment_provider (
    id bigint PRIMARY KEY DEFAULT nextval('public.equipment_provider_id_seq'),
    company_name text NOT NULL,
    contact_phone text,
    contact_email text,
    service_type text,
    created_at timestamptz DEFAULT now()
);

-- VENUE
CREATE TABLE IF NOT EXISTS public.venue (
    id bigint PRIMARY KEY DEFAULT nextval('public.venue_id_seq'),
    name text NOT NULL,
    address text,
    capacity integer CHECK (capacity IS NULL OR capacity >= 0),
    city text,
    created_at timestamptz DEFAULT now()
);

-- STAGE (слабка сутність, ідентифікується venue_id + stage_name)
CREATE TABLE IF NOT EXISTS public.stage (
    venue_id bigint NOT NULL,
    stage_name text NOT NULL,
    capacity integer CHECK (capacity IS NULL OR capacity >= 0),
    stage_type text,
    PRIMARY KEY (venue_id, stage_name),
    CONSTRAINT stage_fk_venue FOREIGN KEY (venue_id) REFERENCES public.venue(id) ON DELETE CASCADE
);

-- FESTIVAL
CREATE TABLE IF NOT EXISTS public.festival (
    id bigint PRIMARY KEY DEFAULT nextval('public.festival_id_seq'),
    name text NOT NULL UNIQUE,
    start_date date NOT NULL,
    end_date date NOT NULL,
    city text,
    director_person_id bigint NOT NULL UNIQUE,   -- 1:1 -> person (директор)
    main_organizer_id bigint NOT NULL UNIQUE,    -- 1:1 -> organizer (головний організатор)
    CHECK (start_date <= end_date),
    created_at timestamptz DEFAULT now(),
    CONSTRAINT festival_director_fk FOREIGN KEY (director_person_id) REFERENCES public.person(id),
    CONSTRAINT festival_main_org_fk FOREIGN KEY (main_organizer_id) REFERENCES public.organizer(id)
);

-- VOLUNTEER_TEAM (слабка сутність, PK = festival_id + team_name)
CREATE TABLE IF NOT EXISTS public.volunteer_team (
    festival_id bigint NOT NULL,
    team_name text NOT NULL,
    coordinator_id bigint,  -- посилання на person
    PRIMARY KEY (festival_id, team_name),
    CONSTRAINT volunteer_team_festival_fk FOREIGN KEY (festival_id) REFERENCES public.festival(id) ON DELETE CASCADE,
    CONSTRAINT volunteer_team_coord_fk FOREIGN KEY (coordinator_id) REFERENCES public.person(id)
);

-- VOLUNTEER_TEAM_PERSON (M:N) — члени команд
CREATE TABLE IF NOT EXISTS public.volunteer_team_person (
    festival_id bigint NOT NULL,
    team_name text NOT NULL,
    person_id bigint NOT NULL,
    role_in_team text,
    PRIMARY KEY (festival_id, team_name, person_id),
    CONSTRAINT volunteer_team_person_team_fk FOREIGN KEY (festival_id, team_name) REFERENCES public.volunteer_team(festival_id, team_name) ON DELETE CASCADE,
    CONSTRAINT volunteer_team_person_person_fk FOREIGN KEY (person_id) REFERENCES public.person(id) ON DELETE CASCADE
);

-- EVENT (подія) з композитним FK (venue_id, stage_name) -> stage
CREATE TABLE IF NOT EXISTS public.event (
    id bigint PRIMARY KEY DEFAULT nextval('public.event_id_seq'),
    festival_id bigint NOT NULL,
    venue_id bigint NOT NULL,
    stage_name text NOT NULL,
    title text NOT NULL,
    start_datetime timestamptz NOT NULL,
    end_datetime timestamptz NOT NULL,
    estimated_budget numeric(14,2),
    CHECK (start_datetime < end_datetime),
    created_at timestamptz DEFAULT now(),
    CONSTRAINT event_festival_fk FOREIGN KEY (festival_id) REFERENCES public.festival(id) ON DELETE CASCADE,
    CONSTRAINT event_stage_fk FOREIGN KEY (venue_id, stage_name) REFERENCES public.stage(venue_id, stage_name) ON DELETE RESTRICT
);

-- ARTIST_EVENT (лайн-ап, M:N)
CREATE TABLE IF NOT EXISTS public.artist_event (
    artist_id bigint NOT NULL,
    event_id bigint NOT NULL,
    PRIMARY KEY (artist_id, event_id),
    CONSTRAINT artist_event_artist_fk FOREIGN KEY (artist_id) REFERENCES public.artist(id) ON DELETE CASCADE,
    CONSTRAINT artist_event_event_fk FOREIGN KEY (event_id) REFERENCES public.event(id) ON DELETE CASCADE
);

-- EQUIPMENT PROVIDER ASSIGNMENT (event <-> equipment_provider) M:N
CREATE TABLE IF NOT EXISTS public.event_equipment_provider (
    event_id bigint NOT NULL,
    provider_id bigint NOT NULL,
    PRIMARY KEY (event_id, provider_id),
    CONSTRAINT eep_event_fk FOREIGN KEY (event_id) REFERENCES public.event(id) ON DELETE CASCADE,
    CONSTRAINT eep_provider_fk FOREIGN KEY (provider_id) REFERENCES public.equipment_provider(id) ON DELETE CASCADE
);

-- CONTRACT (тернарний як таблиця): на пару (artist,event) — exactly one organizer
CREATE TABLE IF NOT EXISTS public.contract (
    artist_id bigint NOT NULL,
    event_id bigint NOT NULL,
    organizer_id bigint NOT NULL,
    PRIMARY KEY (artist_id, event_id),
    CONSTRAINT contract_artist_fk FOREIGN KEY (artist_id) REFERENCES public.artist(id) ON DELETE CASCADE,
    CONSTRAINT contract_event_fk FOREIGN KEY (event_id) REFERENCES public.event(id) ON DELETE CASCADE,
    CONSTRAINT contract_organizer_fk FOREIGN KEY (organizer_id) REFERENCES public.organizer(id) ON DELETE RESTRICT
);

-- BAND_MEMBER (склад гурту) M:N (band -> artist)
CREATE TABLE IF NOT EXISTS public.band_member (
    band_id bigint NOT NULL,     -- посилання на band.artist_id
    artist_id bigint NOT NULL,   -- учасник (artist.id)
    PRIMARY KEY (band_id, artist_id),
    CONSTRAINT band_member_band_fk FOREIGN KEY (band_id) REFERENCES public.band(artist_id) ON DELETE CASCADE,
    CONSTRAINT band_member_artist_fk FOREIGN KEY (artist_id) REFERENCES public.artist(id) ON DELETE CASCADE,
    CONSTRAINT band_member_no_self CHECK (band_id <> artist_id)
);

-- ARTIST_MENTORSHIP (рекурсивне M:N)
CREATE TABLE IF NOT EXISTS public.artist_mentorship (
    mentor_id bigint NOT NULL,
    mentee_id bigint NOT NULL,
    since_date date,
    PRIMARY KEY (mentor_id, mentee_id),
    CONSTRAINT artist_mentorship_mentor_fk FOREIGN KEY (mentor_id) REFERENCES public.artist(id) ON DELETE CASCADE,
    CONSTRAINT artist_mentorship_mentee_fk FOREIGN KEY (mentee_id) REFERENCES public.artist(id) ON DELETE CASCADE,
    CONSTRAINT artist_mentorship_no_self CHECK (mentor_id <> mentee_id)
);

-- =========================
-- 3) Індекси (для швидкості JOIN/фільтрації)
-- =========================
CREATE INDEX IF NOT EXISTS idx_event_festival ON public.event(festival_id);
CREATE INDEX IF NOT EXISTS idx_event_venue_stage ON public.event(venue_id, stage_name);
CREATE INDEX IF NOT EXISTS idx_event_start_end ON public.event(start_datetime, end_datetime);
CREATE INDEX IF NOT EXISTS idx_artist_event_event ON public.artist_event(event_id);
CREATE INDEX IF NOT EXISTS idx_contract_event ON public.contract(event_id);
CREATE INDEX IF NOT EXISTS idx_event_provider_provider ON public.event_equipment_provider(provider_id);
CREATE INDEX IF NOT EXISTS idx_band_member_artist ON public.band_member(artist_id);
CREATE INDEX IF NOT EXISTS idx_person_role ON public.person(role);

-- =========================
-- 4) Додаткові constraint-правила / коментарі (будуть видимі в схемі)
-- =========================
COMMENT ON TABLE public.artist IS 'Artists (solo or band). Use artist_type to distinguish.';
COMMENT ON COLUMN public.artist.artist_type IS 'Allowed: ''solo'', ''band''';
COMMENT ON TABLE public.solo_artist IS 'Solo-artist subtype: additional personal info';
COMMENT ON TABLE public.band IS 'Band subtype: formed_year and genre';
COMMENT ON TABLE public.stage IS 'Stage is weak entity identified by (venue_id, stage_name)';
COMMENT ON TABLE public.festival IS 'Festival: name unique; has director (person) and main organizer (organizer)';
COMMENT ON TABLE public.event IS 'Event: belongs to festival and to a particular stage (venue_id, stage_name)';

-- =========================
-- 5) Безпечна перевірка послідовностей (після імпорту seed даних)
-- Онови sequence до max(id), якщо будуть manual id вставки у seed.sql
-- =========================
-- Використай при потребі:
-- SELECT setval('public.artist_id_seq', COALESCE((SELECT MAX(id) FROM public.artist), 1));
-- SELECT setval('public.person_id_seq', COALESCE((SELECT MAX(id) FROM public.person), 1));
-- SELECT setval('public.organizer_id_seq', COALESCE((SELECT MAX(id) FROM public.organizer), 1));
-- SELECT setval('public.equipment_provider_id_seq', COALESCE((SELECT MAX(id) FROM public.equipment_provider), 1));
-- SELECT setval('public.venue_id_seq', COALESCE((SELECT MAX(id) FROM public.venue), 1));
-- SELECT setval('public.event_id_seq', COALESCE((SELECT MAX(id) FROM public.event), 1));
-- SELECT setval('public.festival_id_seq', COALESCE((SELECT MAX(id) FROM public.festival), 1));

-- =========================
-- END OF SCHEMA
-- =========================
