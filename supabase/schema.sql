-- ProsperFlow — Supabase schema (Backend Plan §3, §6)
-- Run this in the Supabase SQL editor (or `supabase db push`).
--
-- Design rules:
--   * All row IDs are client-generated UUIDs — the key to safe offline sync.
--   * All money columns are integer naira (no decimals anywhere).
--   * Every table carries trader_id; row-level security ensures a trader
--     can only ever touch their own rows (isolation comes from auth.uid(),
--     never from the payload).
--   * Soft deletes via a `deleted` flag so deletions sync like updates.
--
-- Migration guard: the discarded prototype app created tables with a
-- different shape (e.g. an `expenses` table keyed on `user_id`). Any
-- existing table that lacks `trader_id` is renamed to `<name>_legacy` so
-- its data is preserved and the new tables can be created cleanly.
-- Drop the `_legacy` tables manually once you're sure they're not needed.

do $$
declare
  t text;
begin
  foreach t in array array['products', 'sales', 'expenses', 'credits'] loop
    if exists (
      select from information_schema.tables
      where table_schema = 'public' and table_name = t
    ) and not exists (
      select from information_schema.columns
      where table_schema = 'public'
        and table_name = t
        and column_name = 'trader_id'
    ) then
      execute format(
        'alter table public.%I rename to %I', t, t || '_legacy');
    end if;
  end loop;
end $$;

create table if not exists public.products (
  id uuid primary key,
  trader_id uuid not null references auth.users (id) on delete cascade,
  name text not null,
  unit text not null,
  stock integer not null default 0,
  buy_price integer not null,
  sell_price integer not null,
  low_stock_threshold integer not null default 10,
  updated_at timestamptz not null default now(),
  deleted boolean not null default false,
  received_at timestamptz not null default now()
);

create table if not exists public.sales (
  id uuid primary key,
  trader_id uuid not null references auth.users (id) on delete cascade,
  product_id uuid not null,
  qty integer not null check (qty > 0),
  unit_price integer not null,
  total integer not null,
  method text not null check (method in ('cash', 'transfer', 'pos', 'credit')),
  fulfilment text not null check (fulfilment in ('walkIn', 'delivery')),
  customer_name text,
  location text,
  sold_at timestamptz not null, -- device clock at sale time
  received_at timestamptz not null default now()
);

create table if not exists public.expenses (
  id uuid primary key,
  trader_id uuid not null references auth.users (id) on delete cascade,
  description text not null,
  amount integer not null,
  category text not null
    check (category in ('delivery', 'stock', 'rent', 'transport', 'other')),
  spent_on timestamptz not null,
  updated_at timestamptz not null default now(),
  received_at timestamptz not null default now()
);

create table if not exists public.credits (
  sale_id uuid primary key,
  trader_id uuid not null references auth.users (id) on delete cascade,
  customer_name text not null,
  amount integer not null,
  product text not null default '', -- display line, e.g. "Palm Oil (25L) × 2"
  status text not null default 'owed' check (status in ('owed', 'paid')),
  sold_at timestamptz,
  paid_at timestamptz,
  updated_at timestamptz not null default now(),
  received_at timestamptz not null default now()
);

-- Report queries and delta pulls (Backend Plan §3).
create index if not exists sales_trader_sold_at_idx
  on public.sales (trader_id, sold_at);
create index if not exists products_trader_updated_at_idx
  on public.products (trader_id, updated_at);
create index if not exists expenses_trader_updated_at_idx
  on public.expenses (trader_id, updated_at);
create index if not exists credits_trader_updated_at_idx
  on public.credits (trader_id, updated_at);

-- Row-level security: every query is filtered by the trader's auth uid.
alter table public.products enable row level security;
alter table public.sales enable row level security;
alter table public.expenses enable row level security;
alter table public.credits enable row level security;

drop policy if exists "traders manage own products" on public.products;
create policy "traders manage own products" on public.products
  for all to authenticated
  using (trader_id = (select auth.uid()))
  with check (trader_id = (select auth.uid()));

drop policy if exists "traders manage own sales" on public.sales;
create policy "traders manage own sales" on public.sales
  for all to authenticated
  using (trader_id = (select auth.uid()))
  with check (trader_id = (select auth.uid()));

drop policy if exists "traders manage own expenses" on public.expenses;
create policy "traders manage own expenses" on public.expenses
  for all to authenticated
  using (trader_id = (select auth.uid()))
  with check (trader_id = (select auth.uid()));

drop policy if exists "traders manage own credits" on public.credits;
create policy "traders manage own credits" on public.credits
  for all to authenticated
  using (trader_id = (select auth.uid()))
  with check (trader_id = (select auth.uid()));
