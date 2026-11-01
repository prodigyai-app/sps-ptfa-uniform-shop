-- SPS PTFA: import the 25 supplied Christmas photographs as individual stock.
-- Suggested donation: GBP 2 each; initial quantity: one each.
-- Run in this shop's Supabase SQL Editor. Safe to rerun:
-- existing item records and stock quantities/prices are left unchanged.
-- In particular, a reserved item (quantity zero) is NOT replenished.
begin;
do $$
declare r record; v_item_id bigint;
begin
 for r in select * from (values
  ('Matalan red reindeer Christmas jumper', '18-24 months', 'https://prodigyai-app.github.io/sps-ptfa-uniform-shop/assets/christmas/matalan-red-reindeer-christmas-jumper-18-24-months-964a4c07.jpg#rotate=270'),
  ('Tu multicolour Christmas jumper', '2-3 years', 'https://prodigyai-app.github.io/sps-ptfa-uniform-shop/assets/christmas/tu-multicolour-christmas-jumper-2-3-years-12d5ba32.jpg#rotate=270'),
  ('M&S red Christmas cat T-shirt', '3-4 years', 'https://prodigyai-app.github.io/sps-ptfa-uniform-shop/assets/christmas/m-s-red-christmas-cat-t-shirt-3-4-years-df4b6ced.jpg#rotate=270'),
  ('Tu grey penguin Christmas jumper', '3-4 years', 'https://prodigyai-app.github.io/sps-ptfa-uniform-shop/assets/christmas/tu-grey-penguin-christmas-jumper-3-4-years-27315dde.jpg#rotate=270'),
  ('PatPat red reindeer Christmas jumper', '3-4 years', 'https://prodigyai-app.github.io/sps-ptfa-uniform-shop/assets/christmas/patpat-red-reindeer-christmas-jumper-3-4-years-988bf633.jpg#rotate=270'),
  ('Nutmeg white penguin Christmas T-shirt', '4-5 years', 'https://prodigyai-app.github.io/sps-ptfa-uniform-shop/assets/christmas/nutmeg-white-penguin-christmas-t-shirt-4-5-years-d5a781e0.jpg#rotate=270'),
  ('George red sequin reindeer Christmas jumper', '4-5 years', 'https://prodigyai-app.github.io/sps-ptfa-uniform-shop/assets/christmas/george-red-sequin-reindeer-christmas-jumper-4-5-years-753a96f4.jpg#rotate=270'),
  ('Next red reindeer Christmas jumper', '4-5 years', 'https://prodigyai-app.github.io/sps-ptfa-uniform-shop/assets/christmas/next-red-reindeer-christmas-jumper-4-5-years-855a492b.jpg#rotate=270'),
  ('Tu red sunglasses reindeer Christmas jumper', '5 years', 'https://prodigyai-app.github.io/sps-ptfa-uniform-shop/assets/christmas/tu-red-sunglasses-reindeer-christmas-jumper-5-years-252d6e1f.jpg#rotate=270'),
  ('George green Santa Christmas jumper', '5-6 years', 'https://prodigyai-app.github.io/sps-ptfa-uniform-shop/assets/christmas/george-green-santa-christmas-jumper-5-6-years-f0629e95.jpg#rotate=270'),
  ('Tu blue Gruffalo Christmas jumper', '5-6 years', 'https://prodigyai-app.github.io/sps-ptfa-uniform-shop/assets/christmas/tu-blue-gruffalo-christmas-jumper-5-6-years-76d23e5c.jpg#rotate=270'),
  ('Tu pink owl Christmas jumper dress', '5-6 years', 'https://prodigyai-app.github.io/sps-ptfa-uniform-shop/assets/christmas/tu-pink-owl-christmas-jumper-dress-5-6-years-8a95d52e.jpg#rotate=270'),
  ('Primark red fluffy penguin Christmas jumper', '5-6 years', 'https://prodigyai-app.github.io/sps-ptfa-uniform-shop/assets/christmas/primark-red-fluffy-penguin-christmas-jumper-5-6-years-1a4a02dc.jpg#rotate=270'),
  ('George blue penguins Christmas jumper', '5-6 years', 'https://prodigyai-app.github.io/sps-ptfa-uniform-shop/assets/christmas/george-blue-penguins-christmas-jumper-5-6-years-9f56ca67.jpg#rotate=270'),
  ('Tu red patterned Christmas jumper dress', '6-7 years', 'https://prodigyai-app.github.io/sps-ptfa-uniform-shop/assets/christmas/tu-red-patterned-christmas-jumper-dress-6-7-years-23e7ab38.jpg#rotate=270'),
  ('Pepperts black Ho Ho Ho Christmas jumper', '6-8 years', 'https://prodigyai-app.github.io/sps-ptfa-uniform-shop/assets/christmas/pepperts-black-ho-ho-ho-christmas-jumper-6-8-years-fa213ad6.jpg#rotate=270'),
  ('Tu white patterned Christmas jumper', '7 years', 'https://prodigyai-app.github.io/sps-ptfa-uniform-shop/assets/christmas/tu-white-patterned-christmas-jumper-7-years-bc9f8817.jpg#rotate=270'),
  ('Tu navy sequin Christmas cat jumper', '7 years', 'https://prodigyai-app.github.io/sps-ptfa-uniform-shop/assets/christmas/tu-navy-sequin-christmas-cat-jumper-7-years-5913dcff.jpg#rotate=270'),
  ('Next red Santa Christmas T-shirt', '7 years', 'https://prodigyai-app.github.io/sps-ptfa-uniform-shop/assets/christmas/next-red-santa-christmas-t-shirt-7-years-e06766e2.jpg#rotate=270'),
  ('H&M red festive print Christmas T-shirt', '7-8 years', 'https://prodigyai-app.github.io/sps-ptfa-uniform-shop/assets/christmas/h-m-red-festive-print-christmas-t-shirt-7-8-years-1f4952de.jpg#rotate=270'),
  ('Fruit of the Loom red elf Christmas T-shirt', '7-8 years', 'https://prodigyai-app.github.io/sps-ptfa-uniform-shop/assets/christmas/fruit-of-the-loom-red-elf-christmas-t-shirt-7-8-years-27e8dfba.jpg#rotate=270'),
  ('Y.D grey longline snowman Christmas jumper', '7-8 years', 'https://prodigyai-app.github.io/sps-ptfa-uniform-shop/assets/christmas/y-d-grey-longline-snowman-christmas-jumper-7-8-years-f98d9b5e.jpg#rotate=270'),
  ('Generation Fashion red reindeer Christmas jumper', '7-8 years', 'https://prodigyai-app.github.io/sps-ptfa-uniform-shop/assets/christmas/generation-fashion-red-reindeer-christmas-jumper-7-8-years-796eed94.jpg#rotate=270'),
  ('George green Chill penguin Christmas jumper', '8-9 years', 'https://prodigyai-app.github.io/sps-ptfa-uniform-shop/assets/christmas/george-green-chill-penguin-christmas-jumper-8-9-years-03deedca.jpg#rotate=270'),
  ('George red gaming reindeer Christmas jumper', '8-9 years', 'https://prodigyai-app.github.io/sps-ptfa-uniform-shop/assets/christmas/george-red-gaming-reindeer-christmas-jumper-8-9-years-c6f6e48a.jpg#rotate=270')
 ) as supplied(name,size,image_url)
 loop
  select id into v_item_id from public.items where image_url=r.image_url limit 1;
  if not found then
   insert into public.items(name,image_url,category)
   values(r.name,r.image_url,'xmas_jumpers') returning id into v_item_id;
  end if;
  if not exists(select 1 from public.stock where item_id=v_item_id) then
   insert into public.stock(item_id,size,condition,price_pence,quantity)
   values(v_item_id,r.size,'Pre-loved',200,1);
  end if;
 end loop;
end $$;
commit;
select i.name,s.size,s.condition,s.price_pence,s.quantity
from public.items i join public.stock s on s.item_id=i.id
where i.image_url like 'https://prodigyai-app.github.io/sps-ptfa-uniform-shop/assets/christmas/%'
order by i.name;
