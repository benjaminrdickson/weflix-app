-- ACTIVE-ROW ASSUMPTION: Rows are hard-deleted on cancel/reject/end, so every
-- row in this table is active and the check correctly considers all rows.
-- IF a soft-delete or ended-status model is ever introduced, this trigger MUST
-- be updated to filter to active rows only — otherwise a stale row would
-- permanently lock a user out of new relationships.

CREATE OR REPLACE FUNCTION public.check_one_relationship_per_user()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  -- Locks MUST run before the existence check. Taking both prevents the race
  -- where two concurrent inserts each pass the check before either commits.
  PERFORM pg_advisory_xact_lock(hashtext(NEW.sender_id::text));
  PERFORM pg_advisory_xact_lock(hashtext(NEW.recipient_id::text));

  IF EXISTS (
    SELECT 1
    FROM public.relationships
    WHERE
      id IS DISTINCT FROM NEW.id
      AND (
        sender_id    = NEW.sender_id    OR
        recipient_id = NEW.sender_id    OR
        sender_id    = NEW.recipient_id OR
        recipient_id = NEW.recipient_id
      )
  ) THEN
    RAISE EXCEPTION 'User is already in a relationship';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS enforce_one_relationship_per_user ON public.relationships;

CREATE TRIGGER enforce_one_relationship_per_user
  BEFORE INSERT OR UPDATE ON public.relationships
  FOR EACH ROW EXECUTE FUNCTION public.check_one_relationship_per_user();
