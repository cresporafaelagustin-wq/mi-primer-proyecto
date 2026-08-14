-- Migración 014 — Plan de pago por video (cliente)
--
-- Corré esto en el SQL Editor de tu proyecto de Supabase.
--
-- Forma simple de cargar "el cliente me pagó X videos a $Y cada uno,
-- y le pago $Z a cada video al editor" sin depender de cuántas tareas
-- tenga cargadas ni de completar el precio tarea por tarea. Con estos
-- tres números el panel calcula solo cuánto cobraste, cuánto tenés
-- que guardar para el editor, y cuánto es margen tuyo.

alter table public.client_finance
  add column if not exists paid_video_count integer not null default 0,
  add column if not exists sale_price_per_video numeric not null default 0,
  add column if not exists editor_price_per_video numeric not null default 0;
