-- Separate child name while keeping legacy reservations and cached checkout pages compatible.
begin;
alter table public.reservations add column if not exists child_name text;
create or replace function public.reserve_with_child(p_request_id uuid,p_name text,p_class text,p_email text,p_lines jsonb,p_child_name text)
returns jsonb language plpgsql security definer set search_path=public as $$
declare v_payload jsonb;v_existing record;v_result jsonb;v_status text;
begin
 if p_child_name is null or length(trim(p_child_name)) not between 1 and 120 then raise exception 'Invalid child name';end if;
 if p_request_id is null or p_name is null or p_class is null or p_email is null or p_lines is null
 then raise exception 'Missing reservation details';end if;
 if jsonb_typeof(p_lines) is distinct from 'array' then raise exception 'Invalid basket';end if;
 if jsonb_array_length(p_lines) not between 1 and 20 then raise exception 'Invalid basket';end if;
 if exists(select 1 from jsonb_array_elements(p_lines) l where
    jsonb_typeof(l->'stock_id') is distinct from 'number' or
    jsonb_typeof(l->'quantity') is distinct from 'number' or
    (l->>'stock_id') !~ '^[1-9][0-9]*$' or (l->>'quantity') !~ '^[1-9][0-9]*$')
 then raise exception 'Invalid basket entries';end if;
 v_payload:=jsonb_build_object('name',trim(p_name),'child_name',trim(p_child_name),'class',trim(p_class),'email',lower(trim(p_email)),'lines',p_lines);
 -- Serialise retries of the same checkout, including simultaneous requests.
 perform pg_advisory_xact_lock(hashtextextended(p_request_id::text,0));
 select * into v_existing from public.checkout_requests where request_id=p_request_id;
 if found then
  if v_existing.payload<>v_payload then raise exception 'Checkout details changed; start a new checkout';end if;
  select email_status into v_status from public.reservations where id=(v_existing.result->>'id')::uuid;
  return v_existing.result||jsonb_build_object('replayed',true,'email_status',coalesce(v_status,'unknown'));
 end if;
 v_result:=public.place_reservation(p_name,p_class,p_email,p_lines);
 update public.reservations set child_name=trim(p_child_name),email_status='pending' where id=(v_result->>'id')::uuid;
 insert into public.checkout_requests(request_id,payload,result) values(p_request_id,v_payload,v_result);
 return v_result||jsonb_build_object('replayed',false);
end $$;
revoke all on function public.reserve_with_child(uuid,text,text,text,jsonb,text) from public,anon,authenticated;
grant execute on function public.reserve_with_child(uuid,text,text,text,jsonb,text) to service_role;
notify pgrst, 'reload schema';
commit;
