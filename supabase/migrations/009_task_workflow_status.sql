-- Migración 009 — Estado de edición de la tarea (Sin editar / Editando / Revisión / Listo)
--
-- Corré esto en el SQL Editor de tu proyecto de Supabase.

alter table public.tasks
  add column if not exists workflow_status text not null default 'Sin editar';

alter table public.tasks drop constraint if exists tasks_workflow_status_check;
alter table public.tasks
  add constraint tasks_workflow_status_check
  check (workflow_status in ('Sin editar', 'Editando', 'Revisión', 'Listo'));
