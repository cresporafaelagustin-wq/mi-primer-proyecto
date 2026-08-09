-- Migración 006 — Programar el envío diario de recordatorios
--
-- Corré esto DESPUÉS de:
--   1. Correr la migración 005 (columnas de notificación).
--   2. Desplegar la Edge Function "deadline-reminders" (ver
--      SUPABASE_SETUP.md, sección "Recordatorios de entrega").
--
-- Esto programa que, todos los días a las 13:00 UTC (~10hs Argentina),
-- Supabase llame sola a esa función para revisar y mandar los avisos.
--
-- La URL y la clave de abajo ya son las de tu proyecto
-- (tvimwrljadkinizvabac) — no hace falta que cambies nada, salvo que en
-- algún momento migres a otro proyecto de Supabase.

create extension if not exists pg_cron;
create extension if not exists pg_net;

select cron.schedule(
  'sca-deadline-reminders-daily',
  '0 13 * * *',
  $$
  select net.http_post(
    url := 'https://tvimwrljadkinizvabac.supabase.co/functions/v1/deadline-reminders',
    headers := jsonb_build_object(
      'Authorization', 'Bearer sb_publishable_oBh-wTLoOqVTrmGVYrBgvA__0eliAjK',
      'Content-Type', 'application/json'
    ),
    body := '{}'::jsonb
  );
  $$
);

-- Para cambiar el horario más adelante: volvé a correr cron.schedule
-- con el mismo nombre ('sca-deadline-reminders-daily') y el horario
-- nuevo — reemplaza al anterior solo.
--
-- Para desactivarlo del todo:
--   select cron.unschedule('sca-deadline-reminders-daily');
