-- Migración 010 — Link de referencia de edición por tarea
--
-- Corré esto en el SQL Editor de tu proyecto de Supabase.

alter table public.tasks
  add column if not exists edit_reference_link text not null default '';
