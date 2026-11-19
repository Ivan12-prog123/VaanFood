-- VaanFood: skema minimum untuk adapter Supabase yang ada di index.html.
-- Jalankan di Supabase Dashboard > SQL Editor setelah membuat project.

create table if not exists public.kv (
  key text primary key,
  value jsonb not null,
  updated_at timestamptz not null default now()
);

create table if not exists public.orders (
  id text primary key,
  data jsonb not null,
  created_at timestamptz not null default now()
);

create table if not exists public.reviews (
  id text primary key,
  data jsonb not null,
  created_at timestamptz not null default now()
);

alter table public.kv enable row level security;
alter table public.orders enable row level security;
alter table public.reviews enable row level security;

-- Menu, promo, iklan, hero, dan QRIS boleh dibaca pengunjung.
grant select on public.kv to anon, authenticated;
grant insert, update, delete on public.kv to authenticated;
create policy "VaanFood public read kv" on public.kv
  for select to anon, authenticated using (true);
create policy "VaanFood admin insert kv" on public.kv
  for insert to authenticated
  with check ((auth.jwt() -> 'app_metadata' ->> 'role') = 'admin');
create policy "VaanFood admin update kv" on public.kv
  for update to authenticated
  using ((auth.jwt() -> 'app_metadata' ->> 'role') = 'admin')
  with check ((auth.jwt() -> 'app_metadata' ->> 'role') = 'admin');
create policy "VaanFood admin delete kv" on public.kv
  for delete to authenticated
  using ((auth.jwt() -> 'app_metadata' ->> 'role') = 'admin');

-- Pengunjung dapat membuat pesanan, tetapi hanya admin dapat membaca/mengubah
-- seluruh data pesanan (termasuk nomor telepon dan alamat pelanggan).
grant insert on public.orders to anon, authenticated;
grant select, update on public.orders to authenticated;
create policy "VaanFood customer create order" on public.orders
  for insert to anon, authenticated with check (true);
create policy "VaanFood admin read orders" on public.orders
  for select to authenticated
  using ((auth.jwt() -> 'app_metadata' ->> 'role') = 'admin');
create policy "VaanFood admin update orders" on public.orders
  for update to authenticated
  using ((auth.jwt() -> 'app_metadata' ->> 'role') = 'admin')
  with check ((auth.jwt() -> 'app_metadata' ->> 'role') = 'admin');

-- Ulasan dapat dibaca dan dikirim pengunjung. Perubahan/hapus dibatasi admin.
grant select, insert on public.reviews to anon, authenticated;
grant update, delete on public.reviews to authenticated;
create policy "VaanFood public read reviews" on public.reviews
  for select to anon, authenticated using (true);
create policy "VaanFood public submit review" on public.reviews
  for insert to anon, authenticated with check (true);
create policy "VaanFood admin update reviews" on public.reviews
  for update to authenticated
  using ((auth.jwt() -> 'app_metadata' ->> 'role') = 'admin')
  with check ((auth.jwt() -> 'app_metadata' ->> 'role') = 'admin');
create policy "VaanFood admin delete reviews" on public.reviews
  for delete to authenticated
  using ((auth.jwt() -> 'app_metadata' ->> 'role') = 'admin');

-- Tracking publik hanya mengembalikan status, status pembayaran, dan ETA,
-- bukan alamat/nomor telepon pelanggan.
create or replace function public.get_order(p_id text)
returns jsonb
language sql
security definer
set search_path = public
as $$
  select jsonb_build_object(
    'status', data -> 'status',
    'payStatus', data -> 'payStatus',
    'eta', data -> 'eta'
  )
  from public.orders
  where id = p_id;
$$;
revoke all on function public.get_order(text) from public;
grant execute on function public.get_order(text) to anon, authenticated;

-- Storage bucket untuk foto menu, avatar, foto ulasan, hero, dan QRIS.
insert into storage.buckets (id, name, public)
values ('vaanfood', 'vaanfood', true)
on conflict (id) do update set public = true;

grant select on storage.objects to anon, authenticated;
grant insert, update, delete on storage.objects to authenticated;
create policy "VaanFood public read images" on storage.objects
  for select to anon, authenticated using (bucket_id = 'vaanfood');
create policy "VaanFood admin upload images" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'vaanfood'
    and (auth.jwt() -> 'app_metadata' ->> 'role') = 'admin'
  );
create policy "VaanFood admin update images" on storage.objects
  for update to authenticated
  using (
    bucket_id = 'vaanfood'
    and (auth.jwt() -> 'app_metadata' ->> 'role') = 'admin'
  )
  with check (
    bucket_id = 'vaanfood'
    and (auth.jwt() -> 'app_metadata' ->> 'role') = 'admin'
  );
create policy "VaanFood admin delete images" on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'vaanfood'
    and (auth.jwt() -> 'app_metadata' ->> 'role') = 'admin'
  );
