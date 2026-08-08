-- Migración 004 — Módulo financiero (cuentas, gastos fijos, referentes,
-- finanzas por cliente, reparto de ganancias).
--
-- Corré esto en el SQL Editor de tu proyecto de Supabase.
--
-- Todo lo que se agrega acá es exclusivo para el administrador — los
-- editores no tienen ninguna policy de lectura sobre estas tablas, así
-- que ni siquiera inspeccionando la respuesta de la API pueden ver
-- ingresos, comisiones, saldos de cuentas o el reparto de ganancias.

-- ============================================================
-- TABLAS NUEVAS
-- ============================================================

create table if not exists public.payment_accounts (
  id         uuid primary key default gen_random_uuid(),
  name       text not null,
  balance    numeric not null default 0,
  updated_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create table if not exists public.referrers (
  id                uuid primary key default gen_random_uuid(),
  name              text not null,
  payout_account_id uuid references public.payment_accounts(id) on delete set null,
  created_at        timestamptz not null default now()
);

create table if not exists public.fixed_expenses (
  id                uuid primary key default gen_random_uuid(),
  name              text not null,
  cost              numeric not null default 0,
  payout_account_id uuid references public.payment_accounts(id) on delete set null,
  created_at        timestamptz not null default now()
);

-- Datos financieros por cliente — tabla aparte (no columnas de clients)
-- por el mismo motivo que client_contracts: RLS filtra por fila, no por
-- columna, así que separar es la única forma real de ocultarle esto a
-- los editores.
create table if not exists public.client_finance (
  client_id                uuid primary key references public.clients(id) on delete cascade,
  total_income             numeric not null default 0,
  gateway_fee              numeric not null default 0,
  referrer_id              uuid references public.referrers(id) on delete set null,
  referrer_commission_pct  numeric not null default 0,
  referrer_paid            boolean not null default false,
  payment_account_id       uuid references public.payment_accounts(id) on delete set null,
  updated_at               timestamptz not null default now()
);

-- Reparto de ganancias (ej: 70% para vos, 30% a fondo de reserva).
-- Un admin puede tener su propia configuración, igual que notify_settings.
create table if not exists public.finance_settings (
  owner_id        uuid primary key references auth.users(id) on delete cascade,
  owner_share_pct numeric not null default 70,
  updated_at      timestamptz not null default now()
);

-- Cuenta desde la que se le paga a cada editor (informativo).
alter table public.editors
  add column if not exists payout_account_id uuid references public.payment_accounts(id) on delete set null;

-- ============================================================
-- ROW LEVEL SECURITY — todo admin-only, sin excepciones
-- ============================================================

alter table public.payment_accounts enable row level security;
alter table public.referrers enable row level security;
alter table public.fixed_expenses enable row level security;
alter table public.client_finance enable row level security;
alter table public.finance_settings enable row level security;

drop policy if exists "admin only payment_accounts" on public.payment_accounts;
create policy "admin only payment_accounts" on public.payment_accounts
  for all using (public.current_role() = 'admin') with check (public.current_role() = 'admin');

drop policy if exists "admin only referrers" on public.referrers;
create policy "admin only referrers" on public.referrers
  for all using (public.current_role() = 'admin') with check (public.current_role() = 'admin');

drop policy if exists "admin only fixed_expenses" on public.fixed_expenses;
create policy "admin only fixed_expenses" on public.fixed_expenses
  for all using (public.current_role() = 'admin') with check (public.current_role() = 'admin');

drop policy if exists "admin only client_finance" on public.client_finance;
create policy "admin only client_finance" on public.client_finance
  for all using (public.current_role() = 'admin') with check (public.current_role() = 'admin');

drop policy if exists "owner manage finance_settings" on public.finance_settings;
create policy "owner manage finance_settings" on public.finance_settings
  for all using (owner_id = auth.uid() and public.current_role() = 'admin')
  with check (owner_id = auth.uid() and public.current_role() = 'admin');
