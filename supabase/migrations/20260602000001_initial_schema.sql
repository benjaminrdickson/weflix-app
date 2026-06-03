-- ============================================================
-- TABLES
-- ============================================================

CREATE TABLE public.users (
  id         UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  name       TEXT,
  username   TEXT UNIQUE NOT NULL,
  email      TEXT UNIQUE NOT NULL,
  image_url  TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

CREATE TABLE public.relationships (
  id           BIGSERIAL PRIMARY KEY,
  sender_id    UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  recipient_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  confirmation BOOLEAN DEFAULT FALSE NOT NULL,
  created_at   TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  updated_at   TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

CREATE TABLE public.friendships (
  id           BIGSERIAL PRIMARY KEY,
  sender_id    UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  recipient_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  confirmed    BOOLEAN DEFAULT FALSE NOT NULL,
  created_at   TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  updated_at   TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  UNIQUE(sender_id, recipient_id)
);

CREATE TABLE public.likes (
  id           BIGSERIAL PRIMARY KEY,
  user_id      UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  api_movie_id BIGINT NOT NULL,
  content_type TEXT DEFAULT 'movie' NOT NULL,
  created_at   TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  updated_at   TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

CREATE TABLE public.passes (
  id           BIGSERIAL PRIMARY KEY,
  user_id      UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  api_movie_id BIGINT NOT NULL,
  content_type TEXT DEFAULT 'movie' NOT NULL,
  created_at   TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  updated_at   TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  UNIQUE(user_id, api_movie_id, content_type)
);

CREATE TABLE public.favorites (
  id              BIGSERIAL PRIMARY KEY,
  relationship_id BIGINT NOT NULL REFERENCES public.relationships(id) ON DELETE CASCADE,
  api_movie_id    BIGINT,
  content_type    TEXT DEFAULT 'movie' NOT NULL,
  created_at      TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  updated_at      TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

CREATE TABLE public.groups (
  id         BIGSERIAL PRIMARY KEY,
  name       TEXT NOT NULL,
  creator_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

CREATE INDEX ON public.groups(creator_id);

CREATE TABLE public.group_memberships (
  id         BIGSERIAL PRIMARY KEY,
  group_id   BIGINT NOT NULL REFERENCES public.groups(id) ON DELETE CASCADE,
  user_id    UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  UNIQUE(group_id, user_id)
);

CREATE TABLE public.group_invitations (
  id         BIGSERIAL PRIMARY KEY,
  group_id   BIGINT NOT NULL REFERENCES public.groups(id) ON DELETE CASCADE,
  inviter_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  invitee_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  status     TEXT DEFAULT 'pending' NOT NULL CHECK (status IN ('pending','accepted','declined','approved','rejected')),
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  UNIQUE(group_id, invitee_id)
);

CREATE TABLE public.group_likes (
  id           BIGSERIAL PRIMARY KEY,
  group_id     BIGINT NOT NULL REFERENCES public.groups(id) ON DELETE CASCADE,
  user_id      UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  api_movie_id BIGINT NOT NULL,
  content_type TEXT DEFAULT 'movie' NOT NULL,
  created_at   TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  updated_at   TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  UNIQUE(group_id, user_id, api_movie_id, content_type)
);

CREATE TABLE public.group_watchlist_items (
  id           BIGSERIAL PRIMARY KEY,
  group_id     BIGINT NOT NULL REFERENCES public.groups(id) ON DELETE CASCADE,
  api_movie_id BIGINT NOT NULL,
  content_type TEXT DEFAULT 'movie' NOT NULL,
  created_at   TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  updated_at   TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  UNIQUE(group_id, api_movie_id, content_type)
);

CREATE TABLE public.notifications (
  id                BIGSERIAL PRIMARY KEY,
  user_id           UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  notification_type TEXT NOT NULL,
  message           TEXT NOT NULL,
  read              BOOLEAN DEFAULT FALSE NOT NULL,
  context           TEXT,
  created_at        TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  updated_at        TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

CREATE INDEX ON public.notifications(user_id, read);

CREATE TABLE public.notification_preferences (
  id                       BIGSERIAL PRIMARY KEY,
  user_id                  UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE UNIQUE,
  friend_requests          BOOLEAN DEFAULT TRUE NOT NULL,
  friend_request_accepted  BOOLEAN DEFAULT TRUE NOT NULL,
  partner_invitations      BOOLEAN DEFAULT TRUE NOT NULL,
  partner_watchlist_matches BOOLEAN DEFAULT TRUE NOT NULL,
  group_invitations        BOOLEAN DEFAULT TRUE NOT NULL,
  group_watchlist_matches  BOOLEAN DEFAULT TRUE NOT NULL,
  group_join_requests      BOOLEAN DEFAULT TRUE NOT NULL,
  created_at               TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  updated_at               TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

CREATE TABLE public.push_tokens (
  id         BIGSERIAL PRIMARY KEY,
  user_id    UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE UNIQUE,
  token      TEXT NOT NULL UNIQUE,
  platform   TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- ============================================================
-- TRIGGERS
-- ============================================================

-- Auto-create public.users row on Supabase Auth signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.users (id, email, name, username)
  VALUES (
    NEW.id,
    NEW.email,
    NEW.raw_user_meta_data->>'name',
    NEW.raw_user_meta_data->>'username'
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();

-- Auto-create notification_preferences row when a user row is created
CREATE OR REPLACE FUNCTION public.handle_new_user_preferences()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.notification_preferences (user_id)
  VALUES (NEW.id);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_user_created_preferences
  AFTER INSERT ON public.users
  FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user_preferences();

-- ============================================================
-- ROW LEVEL SECURITY
-- ============================================================

ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.relationships ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.friendships ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.likes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.passes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.favorites ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.group_memberships ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.group_invitations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.group_likes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.group_watchlist_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notification_preferences ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.push_tokens ENABLE ROW LEVEL SECURITY;

-- users
CREATE POLICY "users_select" ON public.users FOR SELECT TO authenticated USING (true);
CREATE POLICY "users_insert" ON public.users FOR INSERT WITH CHECK (true);
CREATE POLICY "users_update" ON public.users FOR UPDATE TO authenticated USING (auth.uid() = id);
CREATE POLICY "users_delete" ON public.users FOR DELETE TO authenticated USING (auth.uid() = id);

-- relationships
CREATE POLICY "relationships_select" ON public.relationships FOR SELECT TO authenticated
  USING (auth.uid() = sender_id OR auth.uid() = recipient_id);
CREATE POLICY "relationships_insert" ON public.relationships FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = sender_id);
CREATE POLICY "relationships_update" ON public.relationships FOR UPDATE TO authenticated
  USING (auth.uid() = sender_id OR auth.uid() = recipient_id);
CREATE POLICY "relationships_delete" ON public.relationships FOR DELETE TO authenticated
  USING (auth.uid() = sender_id OR auth.uid() = recipient_id);

-- friendships
CREATE POLICY "friendships_select" ON public.friendships FOR SELECT TO authenticated
  USING (auth.uid() = sender_id OR auth.uid() = recipient_id);
CREATE POLICY "friendships_insert" ON public.friendships FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = sender_id);
CREATE POLICY "friendships_update" ON public.friendships FOR UPDATE TO authenticated
  USING (auth.uid() = sender_id OR auth.uid() = recipient_id);
CREATE POLICY "friendships_delete" ON public.friendships FOR DELETE TO authenticated
  USING (auth.uid() = sender_id OR auth.uid() = recipient_id);

-- likes
CREATE POLICY "likes_all" ON public.likes FOR ALL TO authenticated
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- passes
CREATE POLICY "passes_all" ON public.passes FOR ALL TO authenticated
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- favorites
CREATE POLICY "favorites_select" ON public.favorites FOR SELECT TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.relationships r
    WHERE r.id = relationship_id AND (r.sender_id = auth.uid() OR r.recipient_id = auth.uid())
  ));
CREATE POLICY "favorites_insert" ON public.favorites FOR INSERT TO authenticated
  WITH CHECK (EXISTS (
    SELECT 1 FROM public.relationships r
    WHERE r.id = relationship_id AND (r.sender_id = auth.uid() OR r.recipient_id = auth.uid())
  ));
CREATE POLICY "favorites_delete" ON public.favorites FOR DELETE TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.relationships r
    WHERE r.id = relationship_id AND (r.sender_id = auth.uid() OR r.recipient_id = auth.uid())
  ));

-- groups
CREATE POLICY "groups_select" ON public.groups FOR SELECT TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.group_memberships gm WHERE gm.group_id = id AND gm.user_id = auth.uid()
  ));
CREATE POLICY "groups_insert" ON public.groups FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = creator_id);
CREATE POLICY "groups_update" ON public.groups FOR UPDATE TO authenticated
  USING (auth.uid() = creator_id);
CREATE POLICY "groups_delete" ON public.groups FOR DELETE TO authenticated
  USING (auth.uid() = creator_id);

-- group_memberships
CREATE POLICY "group_memberships_select" ON public.group_memberships FOR SELECT TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.group_memberships gm2 WHERE gm2.group_id = group_id AND gm2.user_id = auth.uid()
  ));
CREATE POLICY "group_memberships_insert" ON public.group_memberships FOR INSERT TO authenticated
  WITH CHECK (true);
CREATE POLICY "group_memberships_delete" ON public.group_memberships FOR DELETE TO authenticated
  USING (
    user_id = auth.uid() OR
    EXISTS (SELECT 1 FROM public.groups g WHERE g.id = group_id AND g.creator_id = auth.uid())
  );

-- group_invitations
CREATE POLICY "group_invitations_select" ON public.group_invitations FOR SELECT TO authenticated
  USING (
    invitee_id = auth.uid() OR
    EXISTS (SELECT 1 FROM public.group_memberships gm WHERE gm.group_id = group_id AND gm.user_id = auth.uid())
  );
CREATE POLICY "group_invitations_insert" ON public.group_invitations FOR INSERT TO authenticated
  WITH CHECK (EXISTS (
    SELECT 1 FROM public.group_memberships gm WHERE gm.group_id = group_id AND gm.user_id = auth.uid()
  ));
CREATE POLICY "group_invitations_update" ON public.group_invitations FOR UPDATE TO authenticated
  USING (
    invitee_id = auth.uid() OR
    EXISTS (SELECT 1 FROM public.groups g WHERE g.id = group_id AND g.creator_id = auth.uid())
  );

-- group_likes
CREATE POLICY "group_likes_select" ON public.group_likes FOR SELECT TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.group_memberships gm WHERE gm.group_id = group_id AND gm.user_id = auth.uid()
  ));
CREATE POLICY "group_likes_insert" ON public.group_likes FOR INSERT TO authenticated
  WITH CHECK (
    auth.uid() = user_id AND
    EXISTS (SELECT 1 FROM public.group_memberships gm WHERE gm.group_id = group_id AND gm.user_id = auth.uid())
  );

-- group_watchlist_items
CREATE POLICY "group_watchlist_select" ON public.group_watchlist_items FOR SELECT TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.group_memberships gm WHERE gm.group_id = group_id AND gm.user_id = auth.uid()
  ));
CREATE POLICY "group_watchlist_insert" ON public.group_watchlist_items FOR INSERT TO authenticated
  WITH CHECK (EXISTS (
    SELECT 1 FROM public.group_memberships gm WHERE gm.group_id = group_id AND gm.user_id = auth.uid()
  ));
CREATE POLICY "group_watchlist_delete" ON public.group_watchlist_items FOR DELETE TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.group_memberships gm WHERE gm.group_id = group_id AND gm.user_id = auth.uid()
  ));

-- notifications
CREATE POLICY "notifications_all" ON public.notifications FOR ALL TO authenticated
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- notification_preferences
CREATE POLICY "notification_preferences_all" ON public.notification_preferences FOR ALL TO authenticated
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- push_tokens
CREATE POLICY "push_tokens_all" ON public.push_tokens FOR ALL TO authenticated
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
