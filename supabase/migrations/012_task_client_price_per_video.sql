-- Migración 012 — Precio por video que se le cobra al cliente
--
-- Corré esto en el SQL Editor de tu proyecto de Supabase.
--
-- Hasta ahora "Precio por video" en una tarea era solo lo que se le paga
-- al editor. Esta columna nueva guarda lo que se le cobra al cliente por
-- ese mismo video, para poder calcular el margen real por video (venta
-- al cliente menos pago al editor) en vez de depender de un total suelto.

alter table public.tasks
  add column if not exists client_price_per_video numeric not null default 0;
