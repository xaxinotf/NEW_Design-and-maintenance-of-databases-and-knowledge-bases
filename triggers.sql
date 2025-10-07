-- ===================================================================
-- TRIGGERS & FUNCTIONS: festival_db
-- ===================================================================

-- 1) Перевірка мінімального бюджету події
CREATE OR REPLACE FUNCTION public.check_event_budget() RETURNS trigger AS $$
BEGIN
    IF NEW.estimated_budget IS NULL OR NEW.estimated_budget < 10000 THEN
        RAISE EXCEPTION 'Budget for event "%" is too low (minimum is 10000)', NEW.title;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_check_event_budget
BEFORE INSERT OR UPDATE ON public.event
FOR EACH ROW EXECUTE FUNCTION public.check_event_budget();


-- 2) Перевірка доступності провайдера обладнання
CREATE OR REPLACE FUNCTION public.check_provider_availability() RETURNS trigger AS $$
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
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_check_provider_availability
BEFORE INSERT OR UPDATE ON public.event_equipment_provider
FOR EACH ROW EXECUTE FUNCTION public.check_provider_availability();


-- 3) Заборона циклів у менторстві
CREATE OR REPLACE FUNCTION public.prevent_mentorship_cycles() RETURNS trigger AS $$
DECLARE cycle_found BOOLEAN;
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
    ) INTO cycle_found;

    IF cycle_found THEN
        RAISE EXCEPTION 'Mentorship cycle detected: adding (%) -> (%) creates a loop',
            NEW.mentor_id, NEW.mentee_id;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_prevent_mentorship_cycles
BEFORE INSERT OR UPDATE ON public.artist_mentorship
FOR EACH ROW EXECUTE FUNCTION public.prevent_mentorship_cycles();
