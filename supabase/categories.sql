-- Repeatable category update; existing items remain normal school uniform.
alter table public.items add column if not exists category text not null default 'uniform';
do $$ begin
 if not exists (select 1 from pg_constraint where conrelid='public.items'::regclass and conname='items_category_check') then
  alter table public.items add constraint items_category_check check(category in ('uniform','xmas_jumpers'));
 end if;
end $$;
