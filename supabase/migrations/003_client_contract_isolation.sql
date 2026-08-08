-- Migración 003 — Separar el contrato en su propia tabla (solo admin) y
-- sumar Referencias / Manual de marca a la ficha de cliente.
--
-- Corré esto en el SQL Editor de tu proyecto de Supabase. Es seguro
-- correrlo tanto si ya ejecutaste la migración 002 como si no.
--
-- Por qué una tabla aparte para el contrato: a diferencia del resto de
-- los campos del cliente (que los editores pueden ver de solo lectura),
-- el link del contrato tiene que quedar oculto para editores a nivel de
-- base de datos, no solo escondido en la pantalla. Row Level Security
-- en Supabase filtra por fila, no por columna, así que la forma correcta
-- de ocultar un campo puntual es sacarlo a su propia tabla con su propia
-- regla de acceso.

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

-- Si contract_link todavía vive en clients (de la migración 002), migrar
-- los datos existentes a la tabla nueva y borrar la columna vieja.
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
