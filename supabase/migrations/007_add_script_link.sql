-- Migración 007 — Link de guión por tarea
--
-- Corré esto en el SQL Editor de tu proyecto de Supabase.

alter table public.tasks
  add column if not exists script_link text not null default '';
