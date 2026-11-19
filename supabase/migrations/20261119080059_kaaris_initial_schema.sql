create table public.training_profiles (
    user_id uuid primary key references auth.users(id) on delete cascade default auth.uid(),
    adult_confirmed_at timestamptz not null,
    goal text not null check (goal in ('strength', 'muscle', 'fitness', 'weight_loss')),
    sessions_per_week integer not null check (sessions_per_week between 2 and 6),
    experience text not null check (experience in ('beginner', 'intermediate', 'advanced')),
    time_zone text not null check (char_length(time_zone) between 1 and 80),
    updated_at timestamptz not null default now()
);

create table public.coach_preferences (
    user_id uuid primary key references auth.users(id) on delete cascade default auth.uid(),
    intensity integer not null default 0 check (intensity between 0 and 4),
    reminders integer not null default 1 check (reminders between 0 and 4),
    ego integer not null default 0 check (ego between 0 and 4),
    blunt_tone_consented_at timestamptz,
    quiet_start time not null default '21:00',
    quiet_end time not null default '08:00',
    muted_until timestamptz,
    updated_at timestamptz not null default now(),
    check ((intensity = 0 and ego = 0) or blunt_tone_consented_at is not null)
);

create table public.workout_sessions (
    user_id uuid not null references auth.users(id) on delete cascade default auth.uid(),
    id uuid not null default gen_random_uuid(),
    title text not null check (char_length(title) between 1 and 100),
    starts_at timestamptz not null,
    ends_at timestamptz not null,
    primary key (user_id, id),
    check (ends_at > starts_at)
);

create index workout_sessions_user_starts_at
    on public.workout_sessions (user_id, starts_at);

create table public.workout_checkins (
    user_id uuid not null default auth.uid(),
    session_id uuid not null,
    result text not null check (result in ('arrived', 'completed', 'skipped')),
    recorded_at timestamptz not null default now(),
    primary key (user_id, session_id),
    foreign key (user_id, session_id) references public.workout_sessions(user_id, id) on delete cascade
);

create table public.kaaris_google_states (
    state_hash text primary key check (state_hash ~ '^[0-9a-f]{64}$'),
    user_id uuid not null unique references auth.users(id) on delete cascade,
    verifier_encrypted text not null,
    expires_at timestamptz not null
);

create index kaaris_google_states_expires_at on public.kaaris_google_states (expires_at);

create table public.kaaris_google_connections (
    user_id uuid primary key references auth.users(id) on delete cascade,
    google_subject text not null,
    refresh_token_encrypted text not null,
    calendar_id text,
    updated_at timestamptz not null default now()
);

alter table public.training_profiles enable row level security;
alter table public.coach_preferences enable row level security;
alter table public.workout_sessions enable row level security;
alter table public.workout_checkins enable row level security;
alter table public.kaaris_google_states enable row level security;
alter table public.kaaris_google_connections enable row level security;

revoke all on public.training_profiles, public.coach_preferences,
    public.workout_sessions, public.workout_checkins,
    public.kaaris_google_states, public.kaaris_google_connections
    from public, anon, authenticated;

grant select, insert, update, delete on public.training_profiles,
    public.coach_preferences, public.workout_sessions, public.workout_checkins to authenticated;
grant select, insert, update, delete on public.kaaris_google_states,
    public.kaaris_google_connections to service_role;

create policy own_training_profile on public.training_profiles
    for all to authenticated using (user_id = (select auth.uid()))
    with check (user_id = (select auth.uid()));
create policy own_coach_preferences on public.coach_preferences
    for all to authenticated using (user_id = (select auth.uid()))
    with check (user_id = (select auth.uid()));
create policy own_workout_sessions on public.workout_sessions
    for all to authenticated using (user_id = (select auth.uid()))
    with check (user_id = (select auth.uid()));
create policy own_workout_checkins on public.workout_checkins
    for all to authenticated using (user_id = (select auth.uid()))
    with check (user_id = (select auth.uid()));
