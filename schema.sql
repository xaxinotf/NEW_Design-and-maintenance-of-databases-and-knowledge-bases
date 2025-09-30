--
-- PostgreSQL database dump
--

\restrict EXefchIjsf7fgQsg7Bq5bWAxABgClPGCRPVSBuLewxNd2rIgzmyc9BaeYw26DKg

-- Dumped from database version 17.6
-- Dumped by pg_dump version 17.6

-- Started on 2025-09-30 23:35:38

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- TOC entry 243 (class 1255 OID 17411)
-- Name: check_event_budget(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.check_event_budget() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NEW.estimated_budget IS NULL OR NEW.estimated_budget < 10000 THEN
        RAISE EXCEPTION 'Budget for event "%" is too low (minimum is 10000)', NEW.title;
    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.check_event_budget() OWNER TO postgres;

--
-- TOC entry 242 (class 1255 OID 17409)
-- Name: check_provider_availability(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.check_provider_availability() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE s1 timestamptz; e1 timestamptz;
BEGIN
  SELECT start_datetime, end_datetime INTO s1,e1 FROM event WHERE id = NEW.event_id;
  IF EXISTS (
    SELECT 1
    FROM event_equipment_provider x
    JOIN event e ON e.id = x.event_id
    WHERE x.provider_id = NEW.provider_id
      AND x.event_id <> NEW.event_id
      AND tstzrange(e.start_datetime,e.end_datetime,'[)') &&
          tstzrange(s1,e1,'[)')
  ) THEN
    RAISE EXCEPTION 'Provider % already booked on overlapping event', NEW.provider_id;
  END IF;
  RETURN NEW;
END $$;


ALTER FUNCTION public.check_provider_availability() OWNER TO postgres;

--
-- TOC entry 241 (class 1255 OID 17398)
-- Name: prevent_mentorship_cycles(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.prevent_mentorship_cycles() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    cycle_found BOOLEAN;
BEGIN
    IF NEW.mentor_id = NEW.mentee_id THEN
        RAISE EXCEPTION 'Mentor and mentee must be different';
    END IF;

    WITH RECURSIVE g AS (
        SELECT mentor_id, mentee_id FROM artist_mentorship
        UNION ALL
        SELECT NEW.mentor_id, NEW.mentee_id
    ),
    reach(mentor_id, mentee_id) AS (
        SELECT mentor_id, mentee_id FROM g
        UNION
        SELECT r.mentor_id, g.mentee_id
        FROM reach r JOIN g ON g.mentor_id = r.mentee_id
    )
    SELECT EXISTS (
        SELECT 1 FROM reach
        WHERE mentor_id = NEW.mentee_id AND mentee_id = NEW.mentor_id
    )
    INTO cycle_found;

    IF cycle_found THEN
        RAISE EXCEPTION 'Mentorship cycle detected: adding (%) -> (%) creates a loop',
            NEW.mentor_id, NEW.mentee_id;
    END IF;

    RETURN NEW;
END;
$$;


ALTER FUNCTION public.prevent_mentorship_cycles() OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- TOC entry 218 (class 1259 OID 17154)
-- Name: artist; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.artist (
    id bigint NOT NULL,
    display_name text NOT NULL,
    country text,
    artist_type text NOT NULL,
    CONSTRAINT artist_artist_type_check CHECK ((artist_type = ANY (ARRAY['solo'::text, 'band'::text])))
);


ALTER TABLE public.artist OWNER TO postgres;

--
-- TOC entry 236 (class 1259 OID 17315)
-- Name: artist_event; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.artist_event (
    artist_id bigint NOT NULL,
    event_id bigint NOT NULL
);


ALTER TABLE public.artist_event OWNER TO postgres;

--
-- TOC entry 217 (class 1259 OID 17153)
-- Name: artist_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.artist_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.artist_id_seq OWNER TO postgres;

--
-- TOC entry 5051 (class 0 OID 0)
-- Dependencies: 217
-- Name: artist_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.artist_id_seq OWNED BY public.artist.id;


--
-- TOC entry 239 (class 1259 OID 17362)
-- Name: artist_mentorship; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.artist_mentorship (
    mentor_id bigint NOT NULL,
    mentee_id bigint NOT NULL,
    since_date date,
    CONSTRAINT artist_mentorship_check CHECK ((mentor_id <> mentee_id))
);


ALTER TABLE public.artist_mentorship OWNER TO postgres;

--
-- TOC entry 220 (class 1259 OID 17175)
-- Name: band; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.band (
    artist_id bigint NOT NULL,
    formed_year integer,
    genre text,
    CONSTRAINT band_formed_year_check CHECK (((formed_year >= 1900) AND (formed_year <= (EXTRACT(year FROM now()))::integer)))
);


ALTER TABLE public.band OWNER TO postgres;

--
-- TOC entry 235 (class 1259 OID 17299)
-- Name: band_member; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.band_member (
    band_id bigint NOT NULL,
    artist_id bigint NOT NULL,
    CONSTRAINT band_member_check CHECK ((band_id <> artist_id))
);


ALTER TABLE public.band_member OWNER TO postgres;

--
-- TOC entry 240 (class 1259 OID 17378)
-- Name: contract; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.contract (
    artist_id bigint NOT NULL,
    event_id bigint NOT NULL,
    organizer_id bigint NOT NULL
);


ALTER TABLE public.contract OWNER TO postgres;

--
-- TOC entry 226 (class 1259 OID 17207)
-- Name: equipment_provider; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.equipment_provider (
    id bigint NOT NULL,
    company_name text NOT NULL,
    contact_phone text,
    contact_email text,
    service_type text
);


ALTER TABLE public.equipment_provider OWNER TO postgres;

--
-- TOC entry 225 (class 1259 OID 17206)
-- Name: equipment_provider_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.equipment_provider_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.equipment_provider_id_seq OWNER TO postgres;

--
-- TOC entry 5052 (class 0 OID 0)
-- Dependencies: 225
-- Name: equipment_provider_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.equipment_provider_id_seq OWNED BY public.equipment_provider.id;


--
-- TOC entry 234 (class 1259 OID 17280)
-- Name: event; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.event (
    id bigint NOT NULL,
    festival_id bigint NOT NULL,
    venue_id bigint NOT NULL,
    stage_name text NOT NULL,
    title text NOT NULL,
    start_datetime timestamp with time zone NOT NULL,
    end_datetime timestamp with time zone NOT NULL,
    estimated_budget numeric(14,2),
    CONSTRAINT event_check CHECK ((start_datetime < end_datetime))
);


ALTER TABLE public.event OWNER TO postgres;

--
-- TOC entry 237 (class 1259 OID 17330)
-- Name: event_equipment_provider; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.event_equipment_provider (
    event_id bigint NOT NULL,
    provider_id bigint NOT NULL
);


ALTER TABLE public.event_equipment_provider OWNER TO postgres;

--
-- TOC entry 233 (class 1259 OID 17279)
-- Name: event_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.event_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.event_id_seq OWNER TO postgres;

--
-- TOC entry 5053 (class 0 OID 0)
-- Dependencies: 233
-- Name: event_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.event_id_seq OWNED BY public.event.id;


--
-- TOC entry 231 (class 1259 OID 17239)
-- Name: festival; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.festival (
    id bigint NOT NULL,
    name text NOT NULL,
    start_date date NOT NULL,
    end_date date NOT NULL,
    city text,
    director_person_id bigint NOT NULL,
    main_organizer_id bigint NOT NULL,
    CONSTRAINT festival_check CHECK ((start_date <= end_date))
);


ALTER TABLE public.festival OWNER TO postgres;

--
-- TOC entry 230 (class 1259 OID 17238)
-- Name: festival_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.festival_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.festival_id_seq OWNER TO postgres;

--
-- TOC entry 5054 (class 0 OID 0)
-- Dependencies: 230
-- Name: festival_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.festival_id_seq OWNED BY public.festival.id;


--
-- TOC entry 224 (class 1259 OID 17198)
-- Name: organizer; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.organizer (
    id bigint NOT NULL,
    org_name text NOT NULL,
    contact_email text,
    contact_phone text,
    address text
);


ALTER TABLE public.organizer OWNER TO postgres;

--
-- TOC entry 223 (class 1259 OID 17197)
-- Name: organizer_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.organizer_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.organizer_id_seq OWNER TO postgres;

--
-- TOC entry 5055 (class 0 OID 0)
-- Dependencies: 223
-- Name: organizer_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.organizer_id_seq OWNED BY public.organizer.id;


--
-- TOC entry 222 (class 1259 OID 17189)
-- Name: person; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.person (
    id bigint NOT NULL,
    full_name text NOT NULL,
    email text,
    phone text,
    role text
);


ALTER TABLE public.person OWNER TO postgres;

--
-- TOC entry 221 (class 1259 OID 17188)
-- Name: person_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.person_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.person_id_seq OWNER TO postgres;

--
-- TOC entry 5056 (class 0 OID 0)
-- Dependencies: 221
-- Name: person_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.person_id_seq OWNED BY public.person.id;


--
-- TOC entry 219 (class 1259 OID 17163)
-- Name: solo_artist; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.solo_artist (
    artist_id bigint NOT NULL,
    real_name text NOT NULL,
    birth_date date
);


ALTER TABLE public.solo_artist OWNER TO postgres;

--
-- TOC entry 229 (class 1259 OID 17225)
-- Name: stage; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.stage (
    venue_id bigint NOT NULL,
    stage_name text NOT NULL,
    capacity integer,
    stage_type text,
    CONSTRAINT stage_capacity_check CHECK (((capacity IS NULL) OR (capacity >= 0)))
);


ALTER TABLE public.stage OWNER TO postgres;

--
-- TOC entry 228 (class 1259 OID 17216)
-- Name: venue; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.venue (
    id bigint NOT NULL,
    name text NOT NULL,
    address text,
    capacity integer,
    city text,
    CONSTRAINT venue_capacity_check CHECK (((capacity IS NULL) OR (capacity >= 0)))
);


ALTER TABLE public.venue OWNER TO postgres;

--
-- TOC entry 227 (class 1259 OID 17215)
-- Name: venue_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.venue_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.venue_id_seq OWNER TO postgres;

--
-- TOC entry 5057 (class 0 OID 0)
-- Dependencies: 227
-- Name: venue_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.venue_id_seq OWNED BY public.venue.id;


--
-- TOC entry 232 (class 1259 OID 17262)
-- Name: volunteer_team; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.volunteer_team (
    festival_id bigint NOT NULL,
    team_name text NOT NULL,
    coordinator_id bigint
);


ALTER TABLE public.volunteer_team OWNER TO postgres;

--
-- TOC entry 238 (class 1259 OID 17345)
-- Name: volunteer_team_person; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.volunteer_team_person (
    festival_id bigint NOT NULL,
    team_name text NOT NULL,
    person_id bigint NOT NULL,
    role_in_team text
);


ALTER TABLE public.volunteer_team_person OWNER TO postgres;

--
-- TOC entry 4815 (class 2604 OID 17157)
-- Name: artist id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.artist ALTER COLUMN id SET DEFAULT nextval('public.artist_id_seq'::regclass);


--
-- TOC entry 4818 (class 2604 OID 17210)
-- Name: equipment_provider id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.equipment_provider ALTER COLUMN id SET DEFAULT nextval('public.equipment_provider_id_seq'::regclass);


--
-- TOC entry 4821 (class 2604 OID 17283)
-- Name: event id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.event ALTER COLUMN id SET DEFAULT nextval('public.event_id_seq'::regclass);


--
-- TOC entry 4820 (class 2604 OID 17242)
-- Name: festival id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.festival ALTER COLUMN id SET DEFAULT nextval('public.festival_id_seq'::regclass);


--
-- TOC entry 4817 (class 2604 OID 17201)
-- Name: organizer id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.organizer ALTER COLUMN id SET DEFAULT nextval('public.organizer_id_seq'::regclass);


--
-- TOC entry 4816 (class 2604 OID 17192)
-- Name: person id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.person ALTER COLUMN id SET DEFAULT nextval('public.person_id_seq'::regclass);


--
-- TOC entry 4819 (class 2604 OID 17219)
-- Name: venue id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.venue ALTER COLUMN id SET DEFAULT nextval('public.venue_id_seq'::regclass);


--
-- TOC entry 4864 (class 2606 OID 17319)
-- Name: artist_event artist_event_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.artist_event
    ADD CONSTRAINT artist_event_pkey PRIMARY KEY (artist_id, event_id);


--
-- TOC entry 4872 (class 2606 OID 17367)
-- Name: artist_mentorship artist_mentorship_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.artist_mentorship
    ADD CONSTRAINT artist_mentorship_pkey PRIMARY KEY (mentor_id, mentee_id);


--
-- TOC entry 4831 (class 2606 OID 17162)
-- Name: artist artist_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.artist
    ADD CONSTRAINT artist_pkey PRIMARY KEY (id);


--
-- TOC entry 4861 (class 2606 OID 17304)
-- Name: band_member band_member_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.band_member
    ADD CONSTRAINT band_member_pkey PRIMARY KEY (band_id, artist_id);


--
-- TOC entry 4835 (class 2606 OID 17182)
-- Name: band band_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.band
    ADD CONSTRAINT band_pkey PRIMARY KEY (artist_id);


--
-- TOC entry 4874 (class 2606 OID 17382)
-- Name: contract contract_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.contract
    ADD CONSTRAINT contract_pkey PRIMARY KEY (artist_id, event_id);


--
-- TOC entry 4841 (class 2606 OID 17214)
-- Name: equipment_provider equipment_provider_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.equipment_provider
    ADD CONSTRAINT equipment_provider_pkey PRIMARY KEY (id);


--
-- TOC entry 4867 (class 2606 OID 17334)
-- Name: event_equipment_provider event_equipment_provider_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.event_equipment_provider
    ADD CONSTRAINT event_equipment_provider_pkey PRIMARY KEY (event_id, provider_id);


--
-- TOC entry 4857 (class 2606 OID 17288)
-- Name: event event_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.event
    ADD CONSTRAINT event_pkey PRIMARY KEY (id);


--
-- TOC entry 4847 (class 2606 OID 17251)
-- Name: festival festival_director_person_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.festival
    ADD CONSTRAINT festival_director_person_id_key UNIQUE (director_person_id);


--
-- TOC entry 4849 (class 2606 OID 17249)
-- Name: festival festival_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.festival
    ADD CONSTRAINT festival_name_key UNIQUE (name);


--
-- TOC entry 4851 (class 2606 OID 17247)
-- Name: festival festival_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.festival
    ADD CONSTRAINT festival_pkey PRIMARY KEY (id);


--
-- TOC entry 4839 (class 2606 OID 17205)
-- Name: organizer organizer_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.organizer
    ADD CONSTRAINT organizer_pkey PRIMARY KEY (id);


--
-- TOC entry 4837 (class 2606 OID 17196)
-- Name: person person_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.person
    ADD CONSTRAINT person_pkey PRIMARY KEY (id);


--
-- TOC entry 4833 (class 2606 OID 17169)
-- Name: solo_artist solo_artist_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.solo_artist
    ADD CONSTRAINT solo_artist_pkey PRIMARY KEY (artist_id);


--
-- TOC entry 4845 (class 2606 OID 17232)
-- Name: stage stage_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.stage
    ADD CONSTRAINT stage_pkey PRIMARY KEY (venue_id, stage_name);


--
-- TOC entry 4853 (class 2606 OID 17408)
-- Name: festival uq_festival_main_organizer; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.festival
    ADD CONSTRAINT uq_festival_main_organizer UNIQUE (main_organizer_id);


--
-- TOC entry 4843 (class 2606 OID 17224)
-- Name: venue venue_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.venue
    ADD CONSTRAINT venue_pkey PRIMARY KEY (id);


--
-- TOC entry 4870 (class 2606 OID 17351)
-- Name: volunteer_team_person volunteer_team_person_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.volunteer_team_person
    ADD CONSTRAINT volunteer_team_person_pkey PRIMARY KEY (festival_id, team_name, person_id);


--
-- TOC entry 4855 (class 2606 OID 17268)
-- Name: volunteer_team volunteer_team_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.volunteer_team
    ADD CONSTRAINT volunteer_team_pkey PRIMARY KEY (festival_id, team_name);


--
-- TOC entry 4865 (class 1259 OID 17402)
-- Name: idx_artist_event_event; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_artist_event_event ON public.artist_event USING btree (event_id);


--
-- TOC entry 4862 (class 1259 OID 17405)
-- Name: idx_band_member_artist; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_band_member_artist ON public.band_member USING btree (artist_id);


--
-- TOC entry 4875 (class 1259 OID 17404)
-- Name: idx_contract_event; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_contract_event ON public.contract USING btree (event_id);


--
-- TOC entry 4858 (class 1259 OID 17400)
-- Name: idx_event_festival; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_event_festival ON public.event USING btree (festival_id);


--
-- TOC entry 4868 (class 1259 OID 17403)
-- Name: idx_event_provider_provider; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_event_provider_provider ON public.event_equipment_provider USING btree (provider_id);


--
-- TOC entry 4859 (class 1259 OID 17401)
-- Name: idx_event_stage; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_event_stage ON public.event USING btree (venue_id, stage_name);


--
-- TOC entry 4898 (class 2620 OID 17412)
-- Name: event trg_check_event_budget; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_check_event_budget BEFORE INSERT OR UPDATE ON public.event FOR EACH ROW EXECUTE FUNCTION public.check_event_budget();


--
-- TOC entry 4899 (class 2620 OID 17410)
-- Name: event_equipment_provider trg_check_provider_availability; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_check_provider_availability BEFORE INSERT OR UPDATE ON public.event_equipment_provider FOR EACH ROW EXECUTE FUNCTION public.check_provider_availability();


--
-- TOC entry 4900 (class 2620 OID 17399)
-- Name: artist_mentorship trg_prevent_mentorship_cycles; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_prevent_mentorship_cycles BEFORE INSERT OR UPDATE ON public.artist_mentorship FOR EACH ROW EXECUTE FUNCTION public.prevent_mentorship_cycles();


--
-- TOC entry 4887 (class 2606 OID 17320)
-- Name: artist_event artist_event_artist_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.artist_event
    ADD CONSTRAINT artist_event_artist_id_fkey FOREIGN KEY (artist_id) REFERENCES public.artist(id) ON DELETE CASCADE;


--
-- TOC entry 4888 (class 2606 OID 17325)
-- Name: artist_event artist_event_event_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.artist_event
    ADD CONSTRAINT artist_event_event_id_fkey FOREIGN KEY (event_id) REFERENCES public.event(id) ON DELETE CASCADE;


--
-- TOC entry 4893 (class 2606 OID 17373)
-- Name: artist_mentorship artist_mentorship_mentee_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.artist_mentorship
    ADD CONSTRAINT artist_mentorship_mentee_id_fkey FOREIGN KEY (mentee_id) REFERENCES public.artist(id) ON DELETE CASCADE;


--
-- TOC entry 4894 (class 2606 OID 17368)
-- Name: artist_mentorship artist_mentorship_mentor_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.artist_mentorship
    ADD CONSTRAINT artist_mentorship_mentor_id_fkey FOREIGN KEY (mentor_id) REFERENCES public.artist(id) ON DELETE CASCADE;


--
-- TOC entry 4877 (class 2606 OID 17183)
-- Name: band band_artist_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.band
    ADD CONSTRAINT band_artist_id_fkey FOREIGN KEY (artist_id) REFERENCES public.artist(id) ON DELETE CASCADE;


--
-- TOC entry 4885 (class 2606 OID 17310)
-- Name: band_member band_member_artist_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.band_member
    ADD CONSTRAINT band_member_artist_id_fkey FOREIGN KEY (artist_id) REFERENCES public.artist(id) ON DELETE CASCADE;


--
-- TOC entry 4886 (class 2606 OID 17305)
-- Name: band_member band_member_band_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.band_member
    ADD CONSTRAINT band_member_band_id_fkey FOREIGN KEY (band_id) REFERENCES public.band(artist_id) ON DELETE CASCADE;


--
-- TOC entry 4895 (class 2606 OID 17383)
-- Name: contract contract_artist_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.contract
    ADD CONSTRAINT contract_artist_id_fkey FOREIGN KEY (artist_id) REFERENCES public.artist(id) ON DELETE CASCADE;


--
-- TOC entry 4896 (class 2606 OID 17388)
-- Name: contract contract_event_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.contract
    ADD CONSTRAINT contract_event_id_fkey FOREIGN KEY (event_id) REFERENCES public.event(id) ON DELETE CASCADE;


--
-- TOC entry 4897 (class 2606 OID 17393)
-- Name: contract contract_organizer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.contract
    ADD CONSTRAINT contract_organizer_id_fkey FOREIGN KEY (organizer_id) REFERENCES public.organizer(id) ON DELETE RESTRICT;


--
-- TOC entry 4889 (class 2606 OID 17335)
-- Name: event_equipment_provider event_equipment_provider_event_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.event_equipment_provider
    ADD CONSTRAINT event_equipment_provider_event_id_fkey FOREIGN KEY (event_id) REFERENCES public.event(id) ON DELETE CASCADE;


--
-- TOC entry 4890 (class 2606 OID 17340)
-- Name: event_equipment_provider event_equipment_provider_provider_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.event_equipment_provider
    ADD CONSTRAINT event_equipment_provider_provider_id_fkey FOREIGN KEY (provider_id) REFERENCES public.equipment_provider(id) ON DELETE CASCADE;


--
-- TOC entry 4883 (class 2606 OID 17289)
-- Name: event event_festival_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.event
    ADD CONSTRAINT event_festival_id_fkey FOREIGN KEY (festival_id) REFERENCES public.festival(id) ON DELETE CASCADE;


--
-- TOC entry 4884 (class 2606 OID 17294)
-- Name: event event_venue_id_stage_name_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.event
    ADD CONSTRAINT event_venue_id_stage_name_fkey FOREIGN KEY (venue_id, stage_name) REFERENCES public.stage(venue_id, stage_name) ON DELETE RESTRICT;


--
-- TOC entry 4879 (class 2606 OID 17252)
-- Name: festival festival_director_person_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.festival
    ADD CONSTRAINT festival_director_person_id_fkey FOREIGN KEY (director_person_id) REFERENCES public.person(id);


--
-- TOC entry 4880 (class 2606 OID 17257)
-- Name: festival festival_main_organizer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.festival
    ADD CONSTRAINT festival_main_organizer_id_fkey FOREIGN KEY (main_organizer_id) REFERENCES public.organizer(id);


--
-- TOC entry 4876 (class 2606 OID 17170)
-- Name: solo_artist solo_artist_artist_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.solo_artist
    ADD CONSTRAINT solo_artist_artist_id_fkey FOREIGN KEY (artist_id) REFERENCES public.artist(id) ON DELETE CASCADE;


--
-- TOC entry 4878 (class 2606 OID 17233)
-- Name: stage stage_venue_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.stage
    ADD CONSTRAINT stage_venue_id_fkey FOREIGN KEY (venue_id) REFERENCES public.venue(id) ON DELETE CASCADE;


--
-- TOC entry 4881 (class 2606 OID 17274)
-- Name: volunteer_team volunteer_team_coordinator_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.volunteer_team
    ADD CONSTRAINT volunteer_team_coordinator_id_fkey FOREIGN KEY (coordinator_id) REFERENCES public.person(id);


--
-- TOC entry 4882 (class 2606 OID 17269)
-- Name: volunteer_team volunteer_team_festival_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.volunteer_team
    ADD CONSTRAINT volunteer_team_festival_id_fkey FOREIGN KEY (festival_id) REFERENCES public.festival(id) ON DELETE CASCADE;


--
-- TOC entry 4891 (class 2606 OID 17357)
-- Name: volunteer_team_person volunteer_team_person_festival_id_team_name_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.volunteer_team_person
    ADD CONSTRAINT volunteer_team_person_festival_id_team_name_fkey FOREIGN KEY (festival_id, team_name) REFERENCES public.volunteer_team(festival_id, team_name) ON DELETE CASCADE;


--
-- TOC entry 4892 (class 2606 OID 17352)
-- Name: volunteer_team_person volunteer_team_person_person_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.volunteer_team_person
    ADD CONSTRAINT volunteer_team_person_person_id_fkey FOREIGN KEY (person_id) REFERENCES public.person(id) ON DELETE CASCADE;


-- Completed on 2025-09-30 23:35:38

--
-- PostgreSQL database dump complete
--

\unrestrict EXefchIjsf7fgQsg7Bq5bWAxABgClPGCRPVSBuLewxNd2rIgzmyc9BaeYw26DKg

