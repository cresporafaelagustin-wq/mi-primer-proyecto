-- Migración 011 — Total a cobrar por cliente (para calcular cuánto falta cobrar)
--
-- Corré esto en el SQL Editor de tu proyecto de Supabase.
--
-- Hasta ahora "Monto adeudado" era un número suelto que se cargaba a mano,
-- sin relación con el resto de los datos. Con total_charge (lo que se le
-- cobra en total al cliente) y total_income (lo que ya se cobró, que ya
-- existía) el panel calcula solo cuánto falta cobrar.

alter table public.client_finance
  add column if not exists total_charge numeric not null default 0;
