-- Migración 015 — Portal de cliente: login y acceso propio
--
-- Corré esto en el SQL Editor de tu proyecto de Supabase.
--
-- Agrega un tercer tipo de cuenta ("client") que entra con el mismo login
-- por email/magic-link que ya usan admin y editores. Un cliente solo va a
-- poder ver y crear cosas propias (su ficha, sus tareas) — nunca datos de
-- otros clientes ni nada interno del panel.

alter table public.clients
  add column if not exists email text unique;

alter table public.profiles
  add column if not exists client_id uuid references public.clients(id) on delete set null;

alter table public.profiles drop constraint if exists profiles_role_check;
alter table public.profiles
  add constraint profiles_role_check check (role in ('admin','editor','client'));

-- Vincula cada login nuevo con su rol (admin / editor / client) automáticamente.
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

create or replace function public.current_client_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select client_id from public.profiles where id = auth.uid();
$$;

drop policy if exists "client read own row" on public.clients;
create policy "client read own row" on public.clients
  for select using (id = public.current_client_id());
