-- Migración 005 — Recordatorios de entrega por email
--
-- Corré esto en el SQL Editor de tu proyecto de Supabase.
--
-- Esto solo agrega las columnas donde vive la configuración (email de
-- aviso del editor, y qué recordatorios ya se mandaron). El envío en sí
-- lo hace una Edge Function aparte (ver SUPABASE_SETUP.md, sección
-- "Recordatorios de entrega") — sin eso desplegado, estas columnas no
-- hacen nada todavía.

alter table public.editors
  add column if not exists notification_email text not null default '',
  add column if not exists notification_phone text not null default '';

alter table public.tasks
  add column if not exists reminder_sent_3d boolean not null default false,
  add column if not exists reminder_sent_2d boolean not null default false,
  add column if not exists reminder_sent_1d boolean not null default false;

-- No hace falta tocar RLS: "editor update own row" (ya existe en
-- schema.sql) ya le permite al editor actualizar notification_email y
-- notification_phone de su propia fila, igual que hoy hace con su meta
-- y su tracker link.
