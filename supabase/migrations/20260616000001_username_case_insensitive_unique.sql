-- Make username uniqueness case-insensitive, and trim whitespace at write time.

-- Trim username on every insert/update so the unique index below is never
-- bypassed by leading/trailing whitespace, and stored values stay clean
-- regardless of which code path writes them (signup trigger, edge function, etc).
CREATE OR REPLACE FUNCTION public.trim_username()
RETURNS TRIGGER AS $$
BEGIN
  NEW.username = btrim(NEW.username);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trim_username_before_write
  BEFORE INSERT OR UPDATE ON public.users
  FOR EACH ROW EXECUTE PROCEDURE public.trim_username();

-- Replace the case-sensitive UNIQUE(username) constraint with a case-insensitive
-- unique index — this is the source of truth for username uniqueness.
ALTER TABLE public.users DROP CONSTRAINT users_username_key;

CREATE UNIQUE INDEX users_username_lower_idx ON public.users (lower(username));
