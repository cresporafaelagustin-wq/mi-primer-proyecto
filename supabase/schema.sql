-- Panel de Producción SCA — esquema de base de datos para Supabase
--
-- Cómo usarlo:
--   1. Creá un proyecto en https://supabase.com (plan gratuito alcanza).
--   2. Abrí el SQL Editor del proyecto y pegá este archivo entero. Ejecutalo.
--   3. Revisá el bloque "ADMIN INICIAL" más abajo y confirmá que el email
--      sea el tuyo (o agregá el que corresponda) antes de correr el script,
--      o corré ese INSERT de nuevo después con el email correcto.
--   4. Ver SUPABASE_SETUP.md en la raíz del repo para el resto de los pasos
--      (Auth, URL/anon key en panel-interno.html, etc).
--
-- Modelo de datos: coincide con el documentado en el HANDOFF (editors,
-- clients, tasks, notify-settings), más "profiles" y "admin_emails" que son
-- nuevos y existen solo para resolver quién es admin y qué editor es cada
-- usuario logueado.

create extension if not exists pgcrypto;

-- ============================================================
-- TABLAS
-- ============================================================

-- Cuentas/plataformas de pago (ARQ, BBVA, Binance, etc.). El saldo es un
-- dato manual que el administrador actualiza a mano — no se calcula solo.
create table if not exists public.payment_accounts (
  id         uuid primary key default gen_random_uuid(),
  name       text not null,
  balance    numeric not null default 0,
  updated_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create table if not exists public.editors (
  id                  uuid primary key default gen_random_uuid(),
  name                text not null,
  email               text unique,
  goal                numeric not null default 0,
  tracker_link        text not null default '',
  payout_account_id   uuid references public.payment_accounts(id) on delete set null,
  notification_email  text not null default '',
  notification_phone  text not null default '',
  created_at          timestamptz not null default now()
);

create table if not exists public.clients (
  id                 uuid primary key default gen_random_uuid(),
  name               text not null,
  status             text not null default '',
  instagram_link     text not null default '',
  drive_link         text not null default '',
  tracker_link       text not null default '',
  reference_link     text not null default '',
  brand_manual_link  text not null default '',
  email              text unique,
  created_at         timestamptz not null default now()
);

-- El link del contrato vive en su propia tabla (no como columna de
-- clients) a propósito: es el único dato de cliente que un editor NO
-- debe poder leer. Row Level Security filtra por fila, no por columna,
-- así que separarlo en su propia tabla con su propia policy es la forma
-- correcta de ocultarlo a nivel de base de datos (no solo en la pantalla).
create table if not exists public.client_contracts (
  client_id     uuid primary key references public.clients(id) on delete cascade,
  contract_link text not null default '',
  updated_at    timestamptz not null default now()
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

-- Datos financieros por cliente: aparte de clients por el mismo motivo
-- que client_contracts (ocultarlo de editores a nivel de base de datos).
create table if not exists public.client_finance (
  client_id                uuid primary key references public.clients(id) on delete cascade,
  total_charge             numeric not null default 0,
  total_income             numeric not null default 0,
  gateway_fee              numeric not null default 0,
  referrer_id              uuid references public.referrers(id) on delete set null,
  referrer_commission_pct  numeric not null default 0,
  referrer_paid            boolean not null default false,
  payment_account_id       uuid references public.payment_accounts(id) on delete set null,
  payment_status           text not null default '' check (payment_status in ('', 'Al día', 'Debe', 'No paga')),
  amount_owed              numeric not null default 0,
  paid_video_count         integer not null default 0,
  sale_price_per_video     numeric not null default 0,
  editor_price_per_video   numeric not null default 0,
  updated_at               timestamptz not null default now()
);

create table if not exists public.tasks (
  id              uuid primary key default gen_random_uuid(),
  project         text not null,
  client_id       uuid references public.clients(id) on delete set null,
  editor_id       uuid references public.editors(id) on delete set null,
  video_count     integer not null default 0,
  videos_done     integer not null default 0,
  priority        text not null default 'media' check (priority in ('alta','media','baja')),
  workflow_status text not null default 'Sin editar' check (workflow_status in ('Sin editar','Editando','Revisión','Listo')),
  deadline        date,
  price_per_video numeric not null default 0,
  paid            boolean not null default false,
  raw_link         text not null default '',
  edited_link      text not null default '',
  script_link      text not null default '',
  edit_reference_link text not null default '',
  notes            text not null default '',
  reminder_sent_3d boolean not null default false,
  reminder_sent_2d boolean not null default false,
  reminder_sent_1d boolean not null default false,
  created_at       timestamptz not null default now()
);

-- Precio de venta al cliente por video: aparte de tasks por el mismo motivo
-- que client_contracts/client_finance — un editor puede leer sus propias
-- tareas, pero no debe poder ver cuánto le cobrás al cliente por ellas.
create table if not exists public.task_client_price (
  task_id                 uuid primary key references public.tasks(id) on delete cascade,
  client_price_per_video  numeric not null default 0,
  updated_at              timestamptz not null default now()
);

-- Pedidos que carga un cliente desde su propio portal (login por email, sin
-- contraseña). No es una tarea todavía: el admin lo revisa en la pestaña
-- "Pedidos" y recién ahí lo convierte en una tarea real, asignándole editor
-- y precio. Así un cliente nunca ve ni toca la tabla de tareas.
create table if not exists public.task_requests (
  id           uuid primary key default gen_random_uuid(),
  client_id    uuid not null references public.clients(id) on delete cascade,
  project      text not null,
  video_count  integer not null default 0,
  deadline     date,
  notes        text not null default '',
  status       text not null default 'Pendiente' check (status in ('Pendiente','Convertida','Descartada')),
  created_at   timestamptz not null default now()
);

-- Un admin puede tener su propia config de alertas (email/telefono/plantilla).
create table if not exists public.notify_settings (
  owner_id   uuid primary key references auth.users(id) on delete cascade,
  email      text not null default '',
  phone      text not null default '',
  template   text not null default '',
  updated_at timestamptz not null default now()
);

-- Reparto de ganancias (ej: 70% para el admin, 30% a fondo de reserva).
create table if not exists public.finance_settings (
  owner_id        uuid primary key references auth.users(id) on delete cascade,
  owner_share_pct numeric not null default 70,
  updated_at      timestamptz not null default now()
);

-- Emails que se promueven a admin automáticamente al loguearse por primera vez.
create table if not exists public.admin_emails (
  email text primary key
);

-- Une cada usuario de Supabase Auth con su rol y (si es editor o cliente)
-- su fila en editors/clients.
create table if not exists public.profiles (
  id         uuid primary key references auth.users(id) on delete cascade,
  email      text not null,
  role       text not null default 'editor' check (role in ('admin','editor','client')),
  editor_id  uuid references public.editors(id) on delete set null,
  client_id  uuid references public.clients(id) on delete set null,
  created_at timestamptz not null default now()
);

-- ============================================================
-- ADMIN INICIAL — editá este email antes de correr el script
-- ============================================================
insert into public.admin_emails (email)
values ('cresporafaelagustin@gmail.com')
on conflict (email) do nothing;

-- ============================================================
-- Vincula cada login nuevo con su rol (admin / editor) automáticamente
-- ============================================================
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_role text := 'editor';
  v_editor_id uuid;
  v_client_id uuid;
begin
  if exists (select 1 from public.admin_emails a where lower(a.email) = lower(new.email)) then
    v_role := 'admin';
  end if;

  select id into v_editor_id from public.editors e where lower(e.email) = lower(new.email);

  if v_role = 'editor' and v_editor_id is null then
    select id into v_client_id from public.clients c where lower(c.email) = lower(new.email);
    if v_client_id is not null then
      v_role := 'client';
    end if;
  end if;

  insert into public.profiles (id, email, role, editor_id, client_id)
  values (new.id, new.email, v_role, v_editor_id, v_client_id)
  on conflict (id) do update set email = excluded.email;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ============================================================
-- Helpers para las policies (security definer => no dispara RLS
-- recursivo al leer profiles desde adentro de otra policy)
-- ============================================================
create or replace function public.current_role()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select role from public.profiles where id = auth.uid();
$$;

create or replace function public.current_editor_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select editor_id from public.profiles where id = auth.uid();
$$;

create or replace function public.current_client_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select client_id from public.profiles where id = auth.uid();
$$;

-- ============================================================
-- ROW LEVEL SECURITY
-- ============================================================

alter table public.editors enable row level security;
alter table public.clients enable row level security;
alter table public.client_contracts enable row level security;
alter table public.payment_accounts enable row level security;
alter table public.referrers enable row level security;
alter table public.fixed_expenses enable row level security;
alter table public.client_finance enable row level security;
alter table public.finance_settings enable row level security;
alter table public.tasks enable row level security;
alter table public.task_client_price enable row level security;
alter table public.task_requests enable row level security;
alter table public.notify_settings enable row level security;
alter table public.admin_emails enable row level security;
alter table public.profiles enable row level security;

-- editors: admin puede todo; un editor solo puede ver/editar su propia fila.
drop policy if exists "admin full access editors" on public.editors;
create policy "admin full access editors" on public.editors
  for all using (public.current_role() = 'admin') with check (public.current_role() = 'admin');

drop policy if exists "editor read own row" on public.editors;
create policy "editor read own row" on public.editors
  for select using (id = public.current_editor_id());

drop policy if exists "editor update own row" on public.editors;
create policy "editor update own row" on public.editors
  for update using (id = public.current_editor_id()) with check (id = public.current_editor_id());

-- clients: admin puede todo; un editor puede leer (lo necesita para el
-- buscador de clientes al cargar una tarea) pero no puede modificar.
drop policy if exists "admin full access clients" on public.clients;
create policy "admin full access clients" on public.clients
  for all using (public.current_role() = 'admin') with check (public.current_role() = 'admin');

drop policy if exists "editor read clients" on public.clients;
create policy "editor read clients" on public.clients
  for select using (public.current_role() = 'editor');

drop policy if exists "client read own row" on public.clients;
create policy "client read own row" on public.clients
  for select using (id = public.current_client_id());

-- client_contracts: solo admin puede crear/editar/borrar, y ni lectura para
-- editores — esto es lo que realmente oculta el contrato de un editor, no
-- una decisión de la pantalla. Un cliente sí puede leer su propio contrato
-- (es el contrato QUE ÉL FIRMÓ), nunca el de otro cliente.
drop policy if exists "admin only client_contracts" on public.client_contracts;
create policy "admin only client_contracts" on public.client_contracts
  for all using (public.current_role() = 'admin') with check (public.current_role() = 'admin');

drop policy if exists "client read own contract" on public.client_contracts;
create policy "client read own contract" on public.client_contracts
  for select using (client_id = public.current_client_id());

-- tasks: admin puede todo; un editor solo puede ver/crear/editar/borrar
-- las tareas asignadas a sí mismo.
drop policy if exists "admin full access tasks" on public.tasks;
create policy "admin full access tasks" on public.tasks
  for all using (public.current_role() = 'admin') with check (public.current_role() = 'admin');

drop policy if exists "editor read own tasks" on public.tasks;
create policy "editor read own tasks" on public.tasks
  for select using (editor_id = public.current_editor_id());

drop policy if exists "editor insert own tasks" on public.tasks;
create policy "editor insert own tasks" on public.tasks
  for insert with check (editor_id = public.current_editor_id());

drop policy if exists "editor update own tasks" on public.tasks;
create policy "editor update own tasks" on public.tasks
  for update using (editor_id = public.current_editor_id()) with check (editor_id = public.current_editor_id());

drop policy if exists "editor delete own tasks" on public.tasks;
create policy "editor delete own tasks" on public.tasks
  for delete using (editor_id = public.current_editor_id());

-- task_requests: admin puede todo (revisarlos y convertirlos en tareas);
-- un cliente solo puede crear y leer los pedidos que él mismo cargó.
drop policy if exists "admin full access task_requests" on public.task_requests;
create policy "admin full access task_requests" on public.task_requests
  for all using (public.current_role() = 'admin') with check (public.current_role() = 'admin');

drop policy if exists "client insert own task_requests" on public.task_requests;
create policy "client insert own task_requests" on public.task_requests
  for insert with check (client_id = public.current_client_id());

drop policy if exists "client read own task_requests" on public.task_requests;
create policy "client read own task_requests" on public.task_requests
  for select using (client_id = public.current_client_id());

-- Un cliente ve el estado de sus tareas (para eso está el portal), pero
-- "tasks" tiene columnas que no debe ver bajo ningún concepto (precio al
-- editor, guión, notas internas). Por eso no se le da ninguna policy de
-- acceso directo a "tasks" — solo a esta vista, que ya trae adentro el
-- filtro "es tuya" y solo expone columnas seguras.
create or replace view public.client_visible_tasks as
select
  id, client_id, project, video_count, videos_done,
  workflow_status, deadline, raw_link, edited_link, created_at
from public.tasks
where client_id = public.current_client_id();

grant select on public.client_visible_tasks to authenticated;

-- notify_settings: cada admin ve y edita solo su propia configuración.
drop policy if exists "owner manage notify settings" on public.notify_settings;
create policy "owner manage notify settings" on public.notify_settings
  for all using (owner_id = auth.uid() and public.current_role() = 'admin')
  with check (owner_id = auth.uid() and public.current_role() = 'admin');

-- Módulo financiero: admin-only, sin ninguna policy de lectura para
-- editores. Ni ingresos, ni comisiones, ni saldos, ni el reparto de
-- ganancias son visibles para un editor bajo ningún concepto.
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

drop policy if exists "admin only task_client_price" on public.task_client_price;
create policy "admin only task_client_price" on public.task_client_price
  for all using (public.current_role() = 'admin') with check (public.current_role() = 'admin');

drop policy if exists "owner manage finance_settings" on public.finance_settings;
create policy "owner manage finance_settings" on public.finance_settings
  for all using (owner_id = auth.uid() and public.current_role() = 'admin')
  with check (owner_id = auth.uid() and public.current_role() = 'admin');

-- admin_emails: solo un admin ya existente puede agregar más admins.
drop policy if exists "admin manage admin_emails" on public.admin_emails;
create policy "admin manage admin_emails" on public.admin_emails
  for all using (public.current_role() = 'admin') with check (public.current_role() = 'admin');

-- profiles: cada usuario ve su propia fila; admin ve y gestiona todas
-- (esto es lo que permite vincular a un editor con su email desde el panel).
drop policy if exists "select own or admin profiles" on public.profiles;
create policy "select own or admin profiles" on public.profiles
  for select using (id = auth.uid() or public.current_role() = 'admin');

drop policy if exists "admin manage profiles" on public.profiles;
create policy "admin manage profiles" on public.profiles
  for all using (public.current_role() = 'admin') with check (public.current_role() = 'admin');
