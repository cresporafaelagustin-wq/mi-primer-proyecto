-- Migración 013 — Ocultar el precio de venta al cliente de los editores
--
-- Corré esto en el SQL Editor de tu proyecto de Supabase.
--
-- client_price_per_video (migración 012) vivía como columna de "tasks",
-- una tabla que los editores SÍ pueden leer (son sus propias tareas
-- asignadas). Eso significa que, aunque el panel no se lo mostrara en
-- pantalla, un editor técnicamente podía ver cuánto le cobrás al
-- cliente por video inspeccionando la respuesta de la API. Esta
-- migración lo muda a su propia tabla admin-only — mismo tratamiento
-- que ya tienen el contrato y el resto de las finanzas del cliente.

create table if not exists public.task_client_price (
  task_id                 uuid primary key references public.tasks(id) on delete cascade,
  client_price_per_video  numeric not null default 0,
  updated_at              timestamptz not null default now()
);

alter table public.task_client_price enable row level security;

drop policy if exists "admin only task_client_price" on public.task_client_price;
create policy "admin only task_client_price" on public.task_client_price
  for all using (public.current_role() = 'admin') with check (public.current_role() = 'admin');

-- Migrar los datos existentes de tasks a task_client_price.
do $$
begin
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'tasks' and column_name = 'client_price_per_video'
  ) then
    insert into public.task_client_price (task_id, client_price_per_video)
    select id, client_price_per_video from public.tasks where coalesce(client_price_per_video, 0) <> 0
    on conflict (task_id) do update set client_price_per_video = excluded.client_price_per_video;

    alter table public.tasks drop column client_price_per_video;
  end if;
end $$;
