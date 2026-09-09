-- Migración 016 — Los clientes pueden ver el estado de sus trabajos
--
-- Corré esto en el SQL Editor de tu proyecto de Supabase.
--
-- Un cliente con acceso al portal ahora ve, además de poder pedir videos
-- nuevos, en qué estado están sus tareas ya asignadas (sin editar / editando
-- / revisión / listo), cuántos videos van completados, la fecha de entrega,
-- y los links de material crudo y editado de cada una.
--
-- Ojo con lo mismo de siempre: RLS filtra por fila, no por columna, y la
-- tabla "tasks" tiene columnas que un cliente NO debe ver bajo ningún
-- concepto (lo que le pagás al editor por video, el guión, notas internas,
-- etc). Por eso NO se le da acceso directo a "tasks": se crea una vista que
-- solo expone las columnas seguras, corriendo con los permisos de quien la
-- creó (no los del cliente que consulta) y con el filtro "es tuya" ya
-- adentro de la vista — así ni con las herramientas de desarrollador del
-- navegador un cliente puede pedir la tabla completa.

create or replace view public.client_visible_tasks as
select
  id, client_id, project, video_count, videos_done,
  workflow_status, deadline, raw_link, edited_link, created_at
from public.tasks
where client_id = public.current_client_id();

grant select on public.client_visible_tasks to authenticated;
