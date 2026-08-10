-- CATCHUP — junta las migraciones 002 a 007 en un solo script.
--
-- Usalo cuando no estés seguro de cuáles migraciones ya corriste. Es
-- seguro ejecutarlo entero de una — cada parte usa "if not exists" /
-- "if exists", así que las partes que ya estaban aplicadas simplemente
-- no hacen nada, y las que faltaban se aplican. No borra datos.
--
-- No incluye la migración 006 (programar el envío diario) porque esa
-- necesita que la Edge Function "deadline-reminders" ya esté desplegada
-- — corré esa por separado cuando llegues a ese paso.
--
-- Corré esto entero en el SQL Editor de Supabase y tocá "Run query" en
-- el aviso de confirmación (es normal, agrega columnas/tablas, no borra
-- nada).

-- ============================================================
-- 002 — Ficha de cliente (Instagram, Drive, tracker, pago)
-- ============================================================
alter table public.clients
  add column if not exists payment_status text not null default '',
  add column if not exists amount_owed numeric not null default 0,
  add column if not exists instagram_link text not null default '',
  add column if not exists drive_link text not null default '',
  add column if not exists tracker_link text not null default '';

alter table public.clients drop constraint if exists clients_payment_status_check;
alter table public.clients
  add constraint clients_payment_status_check
  check (payment_status in ('', 'Al día', 'Debe', 'No paga'));

-- ============================================================
-- 003 — Contrato en su propia tabla (admin-only) + Referencias / Manual de marca
-- ============================================================
alter table public.clients
  add column if not exists reference_link text not null default '',
  add column if not exists brand_manual_link text not null default '';

create table if not exists public.client_contracts (
  client_id     uuid primary key references public.clients(id) on delete cascade,
  contract_link text not null default '',
  updated_at    timestamptz not null default now()
);

alter table public.client_contracts enable row level security;

drop policy if exists "admin only client_contracts" on public.client_contracts;
create policy "admin only client_contracts" on public.client_contracts
  for all using (public.current_role() = 'admin') with check (public.current_role() = 'admin');

do $$
begin
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'clients' and column_name = 'contract_link'
  ) then
    insert into public.client_contracts (client_id, contract_link)
    select id, contract_link from public.clients where coalesce(contract_link, '') <> ''
    on conflict (client_id) do update set contract_link = excluded.contract_link;

    alter table public.clients drop column contract_link;
  end if;
end $$;

-- ============================================================
-- 004 — Módulo financiero (cuentas, gastos fijos, referentes, client_finance)
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

create table if not exists public.finance_settings (
  owner_id        uuid primary key references auth.users(id) on delete cascade,
  owner_share_pct numeric not null default 70,
  updated_at      timestamptz not null default now()
);

alter table public.editors
  add column if not exists payout_account_id uuid references public.payment_accounts(id) on delete set null;

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

-- ============================================================
-- 005 — Recordatorios de entrega (columnas de configuración)
-- ============================================================
alter table public.editors
  add column if not exists notification_email text not null default '',
  add column if not exists notification_phone text not null default '';

alter table public.tasks
  add column if not exists reminder_sent_3d boolean not null default false,
  add column if not exists reminder_sent_2d boolean not null default false,
  add column if not exists reminder_sent_1d boolean not null default false;

-- ============================================================
-- 007 — Link de guión por tarea
-- ============================================================
alter table public.tasks
  add column if not exists script_link text not null default '';
