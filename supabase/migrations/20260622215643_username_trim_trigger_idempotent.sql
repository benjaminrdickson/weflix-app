-- Make the trim_username trigger rebuild-safe (idempotent).
-- The original migration (20260616000001) used CREATE TRIGGER without IF NOT EXISTS,
-- which fails on a fresh rebuild. This migration re-declares both objects idempotently.

CREATE OR REPLACE FUNCTION public.trim_username()
RETURNS TRIGGER AS $$
BEGIN
  NEW.username = btrim(NEW.username);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trim_username_before_write ON public.users;
CREATE TRIGGER trim_username_before_write
  BEFORE INSERT OR UPDATE ON public.users
  FOR EACH ROW EXECUTE PROCEDURE public.trim_username();
