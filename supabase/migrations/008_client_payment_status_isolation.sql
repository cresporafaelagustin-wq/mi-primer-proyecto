-- Migración 008 — Ocultar "Estado de pago" y "Debe" de los editores
--
-- Corré esto en el SQL Editor de tu proyecto de Supabase.
--
-- payment_status y amount_owed vivían como columnas de "clients", una
-- tabla que los editores SÍ pueden leer (la necesitan para el buscador
-- de clientes al cargar una tarea). Eso significa que, aunque la
-- pantalla no se lo mostrara, un editor técnicamente podía ver cuánto
-- debe un cliente inspeccionando la respuesta de la API. Esta migración
-- los muda a client_finance, que ya es admin-only — mismo tratamiento
-- que ya tiene el contrato y el resto de las finanzas.

alter table public.client_finance
  add column if not exists payment_status text not null default '',
  add column if not exists amount_owed numeric not null default 0;

alter table public.client_finance drop constraint if exists client_finance_payment_status_check;
alter table public.client_finance
  add constraint client_finance_payment_status_check
  check (payment_status in ('', 'Al día', 'Debe', 'No paga'));

-- Migrar los datos existentes de clients a client_finance.
insert into public.client_finance (client_id, payment_status, amount_owed)
select id, payment_status, amount_owed
from public.clients
where coalesce(payment_status, '') <> '' or coalesce(amount_owed, 0) <> 0
on conflict (client_id) do update
  set payment_status = excluded.payment_status,
      amount_owed = excluded.amount_owed;

-- Borrar las columnas viejas de clients (y su constraint, que ya no aplica ahí).
alter table public.clients drop constraint if exists clients_payment_status_check;
alter table public.clients drop column if exists payment_status;
alter table public.clients drop column if exists amount_owed;
