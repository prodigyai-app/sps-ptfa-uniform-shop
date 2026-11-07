-- Record payments checked by the PTFA; the shop does not automatically verify PayPal payments.
begin;
alter table public.reservations add column if not exists payment_amount_pence integer check(payment_amount_pence between 0 and 10000000);
alter table public.reservations add column if not exists payment_reference text;
alter table public.reservations add column if not exists payment_received_on date;
alter table public.reservations add column if not exists order_notes text;
notify pgrst, 'reload schema';
commit;
