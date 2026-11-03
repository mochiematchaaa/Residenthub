-- ResidentHub database schema (Supabase / PostgreSQL). SCHEMA ONLY: no data, no passwords, no keys.
-- Exported from the live project on 2026-10-16. Run it once in the SQL Editor of a NEW, empty Supabase project.
-- (Authentication users themselves live in Supabase Auth, not in this file.)

-- ============================================================ tables
create table if not exists public.profiles (
  id uuid not null primary key references auth.users(id) on delete cascade,
  email text not null default ''::text,
  name text not null default ''::text,
  phone text not null default ''::text,
  unit text not null default ''::text,
  role text not null default 'resident'::text check (role = any (array['admin'::text, 'resident'::text])),
  suspended boolean not null default false,
  must_change_password boolean not null default false,
  created_at timestamp with time zone not null default now(),
  contact_verified_at timestamp with time zone
);

-- Everything the system stores (units, dues, payments, bookings, announcements, ...) is one row here:
-- kind = what it is, id = its id, unit = who it belongs to ('' = everyone, '__admin' = administrator only), value = the data.
create table if not exists public.records (
  kind text not null,
  id text not null,
  unit text not null default ''::text,
  value jsonb not null default '{}'::jsonb,
  updated_at timestamp with time zone not null default now(),
  primary key (kind, id)
);
create index if not exists records_unit_idx on public.records using btree (unit);
-- two active bookings can never take the same facility, day and time
create unique index if not exists records_booking_slot_uq on public.records using btree (((value ->> 'place'::text)), ((value ->> 'day'::text)), ((value ->> 'slot'::text)))
  where ((kind = 'booking'::text) and ((value ->> 'status'::text) = any (array['Pending'::text, 'Approved'::text])));

-- one-time codes (stored as hashes only); used by the Edge Functions verify-contact and reset-password
create table if not exists public.verification_codes (
  user_id uuid not null references auth.users(id) on delete cascade,
  channel text not null check (channel = any (array['email'::text, 'sms'::text])),
  code_hash text not null,
  expires_at timestamp with time zone not null,
  attempts integer not null default 0,
  sent_at timestamp with time zone not null default now(),
  window_start timestamp with time zone not null default now(),
  sends integer not null default 1,
  primary key (user_id, channel)
);
create table if not exists public.reset_codes (
  user_id uuid not null references auth.users(id) on delete cascade,
  channel text not null check (channel = any (array['email'::text, 'sms'::text])),
  code_hash text not null,
  expires_at timestamp with time zone not null,
  attempts integer not null default 0,
  sent_at timestamp with time zone not null default now(),
  window_start timestamp with time zone not null default now(),
  sends integer not null default 1,
  primary key (user_id, channel)
);

-- ============================================================ helper functions
create or replace function public.is_admin() returns boolean
 language sql stable security definer set search_path to 'public' as $$
  select exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.role = 'admin' and not p.suspended
  );
$$;

-- the unit of the signed-in resident ('' until the resident verified the email/mobile, or when suspended)
create or replace function public.my_unit() returns text
 language sql stable security definer set search_path to 'public' as $$
  select coalesce((
    select p.unit from public.profiles p
    where p.id = auth.uid() and p.role = 'resident' and not p.suspended
      and p.contact_verified_at is not null
  ), '');
$$;

-- kinds every signed-in resident may read
create or replace function public.rec_public_kind(k text) returns boolean
 language sql immutable as $$
  select k in ('announcement','event','doc','poll','vendor','slot','setting','booking','rsvp','vote')
$$;

-- kinds a resident may write for their own unit
create or replace function public.rec_resident_kind(k text) returns boolean
 language sql immutable as $$
  select k in ('booking','grievance','proof','request','statusUpdate','rsvp','vote','unit')
$$;

create or replace function public.handle_new_user() returns trigger
 language plpgsql security definer set search_path to 'public' as $$
begin
  insert into public.profiles (id, email)
  values (new.id, coalesce(new.email, ''))
  on conflict (id) do nothing;
  return new;
end $$;

-- a resident may not change their own role, unit, email, phone, ...
create or replace function public.profiles_guard() returns trigger
 language plpgsql security definer set search_path to 'public' as $$
begin
  if auth.uid() is not null and not public.is_admin() then
    if new.id is distinct from old.id
       or new.role is distinct from old.role
       or new.unit is distinct from old.unit
       or new.suspended is distinct from old.suspended
       or new.email is distinct from old.email
       or new.phone is distinct from old.phone
       or new.contact_verified_at is distinct from old.contact_verified_at then
      raise exception 'Only the administrator can change that.';
    end if;
  end if;
  return new;
end $$;

-- the rules for what a resident may write in `records` (the administrator may write anything)
create or replace function public.records_guard() returns trigger
 language plpgsql security definer set search_path to 'public' as $$
declare
  ov jsonb; nv jsonb; k text;
begin
  new.updated_at := now();
  if auth.uid() is null or public.is_admin() then
    return new;
  end if;
  nv := new.value;
  if tg_op = 'UPDATE' then
    if new.kind is distinct from old.kind or new.id is distinct from old.id
       or new.unit is distinct from old.unit then
      raise exception 'Only the administrator can change that.';
    end if;
    ov := old.value;
    if new.kind = 'activity' then
      raise exception 'Only the administrator can change that.';
    end if;
  end if;

  if new.kind = 'proof' then
    if coalesce(nv->>'status','Pending') <> 'Pending'
       or coalesce(nv->>'receiptNo','') <> ''
       or coalesce(nv->>'direct','false') = 'true' then
      raise exception 'Only the administrator can confirm a payment.';
    end if;
    if tg_op = 'UPDATE' and coalesce(ov->>'status','Pending') <> 'Pending' then
      raise exception 'This payment was already checked by the administrator.';
    end if;
  elsif new.kind = 'booking' then
    if coalesce(nv->>'status','Pending') <> 'Pending' then
      raise exception 'Only the administrator can decide a booking.';
    end if;
    if tg_op = 'UPDATE' and coalesce(ov->>'status','Pending') <> 'Pending' then
      raise exception 'This booking was already decided.';
    end if;
  elsif new.kind = 'grievance' then
    if coalesce(nv->>'stage','0') <> '0' then
      raise exception 'Only the administrator can update a grievance.';
    end if;
    if tg_op = 'UPDATE' and coalesce(ov->>'stage','0') <> '0' then
      raise exception 'This grievance is already being handled.';
    end if;
  elsif new.kind = 'request' then
    if coalesce(nv->>'confirmed','false') = 'true' then
      raise exception 'Only the administrator can confirm a parking request.';
    end if;
    if tg_op = 'UPDATE' and coalesce(ov->>'confirmed','false') = 'true' then
      raise exception 'This request was already confirmed.';
    end if;
  elsif new.kind = 'vote' then
    if tg_op = 'UPDATE' then
      raise exception 'Your unit has already voted in this poll.';
    end if;
    if new.id <> new.unit || '|' || coalesce(nv->>'poll','') then
      raise exception 'Invalid vote.';
    end if;
  elsif new.kind = 'rsvp' then
    if new.id <> new.unit || '|' || coalesce(nv->>'event','') then
      raise exception 'Invalid RSVP.';
    end if;
  elsif new.kind = 'unit' then
    for k in select jsonb_object_keys(coalesce(ov,'{}'::jsonb)) union select jsonb_object_keys(nv) loop
      if (ov->k) is distinct from (nv->k)
         and k not in ('usage','usageStatus','usageRemark','usageInfo','status','statusNote','statusDate') then
        raise exception 'Only the administrator can change unit details.';
      end if;
    end loop;
    if coalesce(nv->>'usageStatus','') not in ('','pending') then
      raise exception 'Only the administrator can approve a usage reading.';
    end if;
  end if;
  return new;
end $$;

-- ============================================================ triggers
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users for each row execute function public.handle_new_user();
drop trigger if exists profiles_guard_trg on public.profiles;
create trigger profiles_guard_trg before update on public.profiles for each row execute function public.profiles_guard();
drop trigger if exists records_guard_trg on public.records;
create trigger records_guard_trg before insert or update on public.records for each row execute function public.records_guard();

-- ============================================================ row level security
alter table public.profiles enable row level security;
alter table public.records enable row level security;
alter table public.verification_codes enable row level security;   -- no policies: only the Edge Functions (service role) can read or write
alter table public.reset_codes enable row level security;          -- no policies: only the Edge Functions (service role) can read or write

drop policy if exists "profiles read own or admin" on public.profiles;
create policy "profiles read own or admin" on public.profiles as permissive for select to authenticated
  using (((id = auth.uid()) or is_admin()));
drop policy if exists "profiles update own or admin" on public.profiles;
create policy "profiles update own or admin" on public.profiles as permissive for update to authenticated
  using (((id = auth.uid()) or is_admin()))
  with check (((id = auth.uid()) or is_admin()));

drop policy if exists "records read" on public.records;
create policy "records read" on public.records as permissive for select to authenticated
  using ((is_admin() or (rec_public_kind(kind) and ((unit = ''::text) or (kind = any (array['booking'::text, 'rsvp'::text, 'vote'::text]))) and (my_unit() <> ''::text)) or ((unit <> ''::text) and (unit = my_unit()))));
drop policy if exists "records insert" on public.records;
create policy "records insert" on public.records as permissive for insert to authenticated
  with check ((is_admin() or ((unit <> ''::text) and (unit = my_unit()) and (kind <> 'unit'::text) and rec_resident_kind(kind)) or ((kind = 'activity'::text) and (unit = '__admin'::text) and (my_unit() <> ''::text))));
drop policy if exists "records update" on public.records;
create policy "records update" on public.records as permissive for update to authenticated
  using ((is_admin() or ((unit <> ''::text) and (unit = my_unit()) and rec_resident_kind(kind))))
  with check ((is_admin() or ((unit <> ''::text) and (unit = my_unit()) and rec_resident_kind(kind))));
drop policy if exists "records delete" on public.records;
create policy "records delete" on public.records as permissive for delete to authenticated
  using ((is_admin() or ((unit <> ''::text) and (unit = my_unit()) and (kind = any (array['request'::text, 'booking'::text, 'rsvp'::text])))));

-- ============================================================ live updates
alter publication supabase_realtime add table public.records;

-- ============================================================ audit trail
-- A locked record of who added, changed or deleted what, and when (with the value before and after).
-- The triggers write it, so the app cannot skip an entry; nobody can edit or delete one (not even the administrator);
-- only the administrator can read it. The activity log and temporary passwords are never copied into it.
-- Changes made by the account tool (Edge Function manage-users) run with the server key, so that function writes its own entries.
create table if not exists public.audit_log (
  id bigint generated always as identity primary key,
  at timestamptz not null default now(),
  actor_id uuid,
  actor_name text not null default '',
  actor_role text not null default '',
  action text not null check (action in ('INSERT','UPDATE','DELETE')),
  source_table text not null,
  kind text not null default '',
  record_id text not null default '',
  unit text not null default '',
  old_value jsonb,
  new_value jsonb
);
create index if not exists audit_log_at_idx on public.audit_log (at desc);

alter table public.audit_log enable row level security;
drop policy if exists audit_admin_read on public.audit_log;
create policy audit_admin_read on public.audit_log for select to authenticated using (public.is_admin());

revoke all on public.audit_log from anon, authenticated;
grant select on public.audit_log to authenticated;
grant select, insert on public.audit_log to service_role;
grant usage on sequence public.audit_log_id_seq to service_role;

create or replace function public.audit_clean(v jsonb)
returns jsonb language plpgsql immutable set search_path = public as $$
begin
  if v is null then return null; end if;
  if jsonb_typeof(v) = 'object' then
    v := v - 'image' - 'photo' - 'proofImage' - 'pw' - 'password';
  end if;
  if length(v::text) > 20000 then
    return jsonb_build_object('note','Value too large to store','size',length(v::text));
  end if;
  return v;
end $$;

create or replace function public.audit_records()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  a_name text := 'System'; a_role text := 'system'; a_id uuid := auth.uid();
  k text; rid text; un text;
begin
  k := coalesce(case when TG_OP='DELETE' then OLD.kind else NEW.kind end,'');
  if k in ('activity','tempcred') then return coalesce(NEW, OLD); end if;
  if TG_OP = 'UPDATE' and OLD.value is not distinct from NEW.value and OLD.unit is not distinct from NEW.unit then
    return NEW;
  end if;
  if a_id is not null then
    select coalesce(nullif(name,''), email), role into a_name, a_role from profiles where id = a_id;
    a_name := coalesce(a_name,'Unknown'); a_role := coalesce(a_role,'');
  end if;
  rid := coalesce(case when TG_OP='DELETE' then OLD.id else NEW.id end,'');
  un  := coalesce(case when TG_OP='DELETE' then OLD.unit else NEW.unit end,'');
  insert into audit_log(actor_id,actor_name,actor_role,action,source_table,kind,record_id,unit,old_value,new_value)
  values (a_id,a_name,a_role,TG_OP,'records',k,rid,un,
    case when TG_OP in ('UPDATE','DELETE') then audit_clean(OLD.value) end,
    case when TG_OP in ('INSERT','UPDATE') then audit_clean(NEW.value) end);
  return coalesce(NEW, OLD);
end $$;

create or replace function public.audit_profiles()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  a_name text; a_role text; a_id uuid := auth.uid();
  o jsonb; n jsonb;
begin
  if a_id is null then return coalesce(NEW, OLD); end if;
  if TG_OP in ('UPDATE','DELETE') then o := to_jsonb(OLD) - 'photo' - 'created_at'; end if;
  if TG_OP in ('INSERT','UPDATE') then n := to_jsonb(NEW) - 'photo' - 'created_at'; end if;
  if TG_OP = 'UPDATE' and o is not distinct from n then return NEW; end if;
  select coalesce(nullif(name,''), email), role into a_name, a_role from profiles where id = a_id;
  insert into audit_log(actor_id,actor_name,actor_role,action,source_table,kind,record_id,unit,old_value,new_value)
  values (a_id,coalesce(a_name,'Unknown'),coalesce(a_role,''),TG_OP,'profiles','account',
    coalesce(case when TG_OP='DELETE' then OLD.id else NEW.id end::text,''),
    coalesce(case when TG_OP='DELETE' then OLD.unit else NEW.unit end,''),o,n);
  return coalesce(NEW, OLD);
end $$;

drop trigger if exists audit_records_trg on public.records;
create trigger audit_records_trg after insert or update or delete on public.records
  for each row execute function public.audit_records();
drop trigger if exists audit_profiles_trg on public.profiles;
create trigger audit_profiles_trg after insert or update or delete on public.profiles
  for each row execute function public.audit_profiles();

create or replace function public.audit_locked()
returns trigger language plpgsql set search_path = public as $$
begin
  raise exception 'The audit trail cannot be changed or deleted.';
end $$;
drop trigger if exists audit_lock_row on public.audit_log;
create trigger audit_lock_row before update or delete on public.audit_log
  for each row execute function public.audit_locked();
drop trigger if exists audit_lock_truncate on public.audit_log;
create trigger audit_lock_truncate before truncate on public.audit_log
  for each statement execute function public.audit_locked();

revoke all on function public.audit_records(), public.audit_profiles(), public.audit_clean(jsonb), public.audit_locked() from public, anon, authenticated;
