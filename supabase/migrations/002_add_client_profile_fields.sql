-- Migración 002 — Ficha de cliente (Instagram, Drive, tracker, pago, contrato)
--
-- Corré esto en el SQL Editor de tu proyecto de Supabase SI ya habías
-- ejecutado supabase/schema.sql antes de que existieran estas columnas.
-- Es seguro correrlo más de una vez (usa "if not exists").
--
-- Si estás armando un proyecto de Supabase nuevo desde cero, no hace
-- falta este archivo: alcanza con supabase/schema.sql, que ya incluye
-- estas columnas.

alter table public.clients
  add column if not exists payment_status text not null default '',
  add column if not exists amount_owed numeric not null default 0,
  add column if not exists instagram_link text not null default '',
  add column if not exists drive_link text not null default '',
  add column if not exists tracker_link text not null default '',
  add column if not exists contract_link text not null default '';

alter table public.clients drop constraint if exists clients_payment_status_check;
alter table public.clients
  add constraint clients_payment_status_check
  check (payment_status in ('', 'Al día', 'Debe', 'No paga'));
