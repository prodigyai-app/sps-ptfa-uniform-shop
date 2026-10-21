-- Run AFTER the original schema.sql (or on the existing shop database).
-- Repeatable; does not recreate tables or remove stock, admins or reservations.
begin;
alter table public.reservations add column if not exists email_status text not null default 'unknown';
create table if not exists public.checkout_requests (
 request_id uuid primary key,
 payload jsonb not null,
 result jsonb not null,
 created_at timestamptz not null default now()
);
alter table public.checkout_requests enable row level security;
revoke all on public.checkout_requests from public, anon, authenticated;
grant all on public.checkout_requests to service_role;

-- Explicit grants avoid depending on a project's default table privileges.
grant usage on schema public to anon, authenticated, service_role;
grant select on public.settings,public.items,public.stock to anon,authenticated;
grant update on public.settings to authenticated;
grant insert,update,delete on public.items,public.stock to authenticated;
grant select on public.reservations,public.reservation_lines to authenticated;
grant usage,select on sequence public.items_id_seq,public.stock_id_seq to authenticated;
grant all on public.reservations,public.reservation_lines to service_role;
-- Existing RLS remains the authority for admin writes and private customer data.

create or replace function public.reserve_once(p_request_id uuid,p_name text,p_class text,p_email text,p_lines jsonb)
returns jsonb language plpgsql security definer set search_path=public as $$
declare v_payload jsonb;v_existing record;v_result jsonb;v_status text;
begin
 if p_request_id is null or p_name is null or p_class is null or p_email is null or p_lines is null
 then raise exception 'Missing reservation details';end if;
 if jsonb_typeof(p_lines) is distinct from 'array' then raise exception 'Invalid basket';end if;
 if jsonb_array_length(p_lines) not between 1 and 20 then raise exception 'Invalid basket';end if;
 if exists(select 1 from jsonb_array_elements(p_lines) l where
    jsonb_typeof(l->'stock_id') is distinct from 'number' or
    jsonb_typeof(l->'quantity') is distinct from 'number' or
    (l->>'stock_id') !~ '^[1-9][0-9]*$' or (l->>'quantity') !~ '^[1-9][0-9]*$')
 then raise exception 'Invalid basket entries';end if;
 v_payload:=jsonb_build_object('name',trim(p_name),'class',trim(p_class),'email',lower(trim(p_email)),'lines',p_lines);
 -- Serialise retries of the same checkout, including simultaneous requests.
 perform pg_advisory_xact_lock(hashtextextended(p_request_id::text,0));
 select * into v_existing from public.checkout_requests where request_id=p_request_id;
 if found then
  if v_existing.payload<>v_payload then raise exception 'Checkout details changed; start a new checkout';end if;
  select email_status into v_status from public.reservations where id=(v_existing.result->>'id')::uuid;
  return v_existing.result||jsonb_build_object('replayed',true,'email_status',coalesce(v_status,'unknown'));
 end if;
 v_result:=public.place_reservation(p_name,p_class,p_email,p_lines);
 update public.reservations set email_status='pending' where id=(v_result->>'id')::uuid;
 insert into public.checkout_requests(request_id,payload,result) values(p_request_id,v_payload,v_result);
 return v_result||jsonb_build_object('replayed',false);
end $$;
revoke all on function public.reserve_once(uuid,text,text,text,jsonb) from public,anon,authenticated;
grant execute on function public.reserve_once(uuid,text,text,text,jsonb) to service_role;
-- Admin photographs are public product images, with server-enforced limits.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('uniform-images','uniform-images',true,5242880,array['image/jpeg','image/png','image/webp','image/gif'])
on conflict(id) do update set public=true,file_size_limit=excluded.file_size_limit,allowed_mime_types=excluded.allowed_mime_types;
commit;
