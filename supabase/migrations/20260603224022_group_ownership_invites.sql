CREATE TABLE public.group_ownership_invites (
  id         BIGSERIAL PRIMARY KEY,
  group_id   BIGINT NOT NULL REFERENCES public.groups(id) ON DELETE CASCADE,
  inviter_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  invitee_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  status     TEXT DEFAULT 'pending' NOT NULL
             CHECK (status IN ('pending','accepted','declined','cancelled')),
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

CREATE UNIQUE INDEX group_ownership_invites_one_pending_idx
  ON public.group_ownership_invites(group_id)
  WHERE (status = 'pending');

ALTER TABLE public.group_ownership_invites ENABLE ROW LEVEL SECURITY;

CREATE POLICY "ownership_invites_select" ON public.group_ownership_invites
  FOR SELECT TO authenticated
  USING (
    inviter_id = auth.uid() OR
    invitee_id = auth.uid() OR
    EXISTS (
      SELECT 1 FROM public.group_memberships gm
      WHERE gm.group_id = group_ownership_invites.group_id
        AND gm.user_id = auth.uid()
    )
  );

CREATE POLICY "ownership_invites_insert" ON public.group_ownership_invites
  FOR INSERT TO authenticated
  WITH CHECK (inviter_id = auth.uid());

CREATE POLICY "ownership_invites_update" ON public.group_ownership_invites
  FOR UPDATE TO authenticated
  USING (inviter_id = auth.uid() OR invitee_id = auth.uid());

CREATE POLICY "ownership_invites_delete" ON public.group_ownership_invites
  FOR DELETE TO authenticated
  USING (inviter_id = auth.uid());
