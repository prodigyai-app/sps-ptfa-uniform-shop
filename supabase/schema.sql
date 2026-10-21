create extension if not exists pgcrypto;
create table public.admins(user_id uuid primary key references auth.users(id) on delete cascade);
create table public.settings(id int primary key default 1 check(id=1),announcement text not null default 'Welcome to the PTFA Used Uniform Shop!');
insert into public.settings(id) values(1);
create table public.items(id bigint generated always as identity primary key,name text not null check(length(name) between 1 and 100),image_url text);
create table public.stock(id bigint generated always as identity primary key,item_id bigint not null references public.items(id) on delete cascade,size text not null,condition text not null default 'Good',price_pence int not null check(price_pence between 0 and 100000),quantity int not null check(quantity between 0 and 10000));
create table public.reservations(id uuid primary key default gen_random_uuid(),parent_name text not null,child_class text not null,email text not null,status text not null default 'reserved' check(status in ('reserved','completed','cancelled')),total_pence int not null default 0,created_at timestamptz not null default now());
create table public.reservation_lines(id bigint generated always as identity primary key,reservation_id uuid not null references public.reservations(id) on delete cascade,stock_id bigint references public.stock(id) on delete set null,item_name text not null,size text not null,condition text not null,price_pence int not null,quantity int not null);
create index on public.stock(item_id);create index on public.reservation_lines(reservation_id);
create or replace function public.is_admin() returns boolean language sql stable security definer set search_path=public as $$ select exists(select 1 from public.admins where user_id=auth.uid()) $$;
revoke all on function public.is_admin() from public;grant execute on function public.is_admin() to authenticated;
alter table public.admins enable row level security;alter table public.settings enable row level security;alter table public.items enable row level security;alter table public.stock enable row level security;alter table public.reservations enable row level security;alter table public.reservation_lines enable row level security;
create policy settings_read on public.settings for select to anon,authenticated using(true);
create policy settings_update on public.settings for update to authenticated using(public.is_admin()) with check(public.is_admin());
create policy items_read on public.items for select to anon,authenticated using(true);
create policy items_insert on public.items for insert to authenticated with check(public.is_admin());
create policy items_update on public.items for update to authenticated using(public.is_admin()) with check(public.is_admin());
create policy items_delete on public.items for delete to authenticated using(public.is_admin());
create policy stock_read on public.stock for select to anon,authenticated using(true);
create policy stock_insert on public.stock for insert to authenticated with check(public.is_admin());
create policy stock_update on public.stock for update to authenticated using(public.is_admin()) with check(public.is_admin());
create policy stock_delete on public.stock for delete to authenticated using(public.is_admin());
create policy reservations_read on public.reservations for select to authenticated using(public.is_admin());
create policy lines_read on public.reservation_lines for select to authenticated using(public.is_admin());
-- Public clients cannot insert orders or edit stock. Only service role can place reservations.
create or replace function public.place_reservation(p_name text,p_class text,p_email text,p_lines jsonb) returns jsonb language plpgsql security definer set search_path=public as $$
declare v_id uuid; v_line jsonb; v_stock record; v_qty int; v_total int:=0; v_lines jsonb:='[]'::jsonb;
begin
 if length(trim(p_name)) not between 2 and 120 or length(trim(p_class)) not between 1 and 80 or length(trim(p_email)) not between 5 and 254 or p_email !~* '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$' then raise exception 'Invalid contact details';end if;
 if jsonb_typeof(p_lines)<>'array' or jsonb_array_length(p_lines) not between 1 and 20 then raise exception 'Basket must have 1 to 20 lines';end if;
 if (select count(distinct (x->>'stock_id')::bigint) from jsonb_array_elements(p_lines) x) <> jsonb_array_length(p_lines) then raise exception 'Duplicate stock entries';end if;
 perform 1 from public.stock where id in (select (x->>'stock_id')::bigint from jsonb_array_elements(p_lines) x) order by id for update;
 insert into public.reservations(parent_name,child_class,email) values(trim(p_name),trim(p_class),lower(trim(p_email))) returning id into v_id;
 for v_line in select value from jsonb_array_elements(p_lines) loop
  v_qty:=(v_line->>'quantity')::int;
  if v_qty not between 1 and 20 then raise exception 'Invalid quantity';end if;
  select s.id,s.size,s.condition,s.price_pence,s.quantity,i.name into v_stock from public.stock s join public.items i on i.id=s.item_id where s.id=(v_line->>'stock_id')::bigint;
  if not found or v_stock.quantity<v_qty then raise exception 'An item is out of stock. Refresh and try again';end if;
  update public.stock set quantity=quantity-v_qty where id=v_stock.id;
  insert into public.reservation_lines(reservation_id,stock_id,item_name,size,condition,price_pence,quantity) values(v_id,v_stock.id,v_stock.name,v_stock.size,v_stock.condition,v_stock.price_pence,v_qty);
  v_total:=v_total+v_stock.price_pence*v_qty;
  v_lines:=v_lines||jsonb_build_array(jsonb_build_object('name',v_stock.name,'size',v_stock.size,'condition',v_stock.condition,'price_pence',v_stock.price_pence,'quantity',v_qty));
 end loop;
 update public.reservations set total_pence=v_total where id=v_id;
 return jsonb_build_object('id',v_id,'total_pence',v_total,'lines',v_lines);
end $$;
revoke all on function public.place_reservation(text,text,text,jsonb) from public,anon,authenticated;grant execute on function public.place_reservation(text,text,text,jsonb) to service_role;
create or replace function public.change_reservation_status(p_id uuid,p_status text) returns void language plpgsql security definer set search_path=public as $$
declare v_old text;r record;
begin
 if not public.is_admin() then raise exception 'Not authorised';end if;
 if p_status not in ('completed','cancelled') then raise exception 'Invalid status';end if;
 select status into v_old from public.reservations where id=p_id for update;
 if not found or v_old='cancelled' then raise exception 'Reservation not found or already cancelled';end if;
 if v_old=p_status then return;end if;
 if p_status='cancelled' then
  for r in select stock_id,quantity from public.reservation_lines where reservation_id=p_id loop
   if r.stock_id is not null then update public.stock set quantity=quantity+r.quantity where id=r.stock_id;end if;
  end loop;
 end if;
 update public.reservations set status=p_status where id=p_id;
end $$;
revoke all on function public.change_reservation_status(uuid,text) from public,anon;grant execute on function public.change_reservation_status(uuid,text) to authenticated;
-- Create a PUBLIC storage bucket named uniform-images using Supabase Storage.
create policy admin_photo_insert on storage.objects for insert to authenticated with check(bucket_id='uniform-images' and public.is_admin());
create policy admin_photo_update on storage.objects for update to authenticated using(bucket_id='uniform-images' and public.is_admin()) with check(bucket_id='uniform-images' and public.is_admin());
create policy admin_photo_delete on storage.objects for delete to authenticated using(bucket_id='uniform-images' and public.is_admin());
