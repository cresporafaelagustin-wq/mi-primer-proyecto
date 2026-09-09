-- Migración 017 — El cliente ve su propio contrato y el link de material crudo
--
-- Corré esto en el SQL Editor de tu proyecto de Supabase, DESPUÉS de la 016.
--
-- Dos cosas:
-- 1) Un cliente ahora puede leer su propio contrato (el que él firmó) desde
--    "client_contracts" — antes esa tabla era admin-only a secas. Sigue sin
--    poder ver el de otro cliente, ni crear/editar/borrar el suyo.
-- 2) La vista client_visible_tasks (migración 016) ahora también expone
--    raw_link (el material crudo), además de edited_link.

drop policy if exists "client read own contract" on public.client_contracts;
create policy "client read own contract" on public.client_contracts
  for select using (client_id = public.current_client_id());

create or replace view public.client_visible_tasks as
select
  id, client_id, project, video_count, videos_done,
  workflow_status, deadline, raw_link, edited_link, created_at
from public.tasks
where client_id = public.current_client_id();
