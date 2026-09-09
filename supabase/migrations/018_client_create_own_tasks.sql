-- Migración 018 — El cliente crea sus propias tareas directamente
--
-- Corré esto en el SQL Editor de tu proyecto de Supabase, DESPUÉS de la 017.
--
-- Antes esto pasaba por una tabla intermedia de "pedidos" que vos tenías
-- que aprobar y convertir en tarea. Se saca ese paso: ahora un cliente
-- carga el pedido y queda directamente como una tarea sin editar en tu
-- pestaña "Tareas" (sin editor asignado, sin precio) — vos solo entrás y
-- le asignás editor y precio como a cualquier tarea nueva.
--
-- El "with check" es la parte importante: un cliente puede INSERTAR una
-- tarea, pero solo si es para sí mismo y queda en blanco (sin editor, sin
-- precio, sin videos hechos, sin marcar como pagada, estado "Sin editar").
-- No tiene ningún otro permiso sobre "tasks" — no puede leerla directo (lee
-- por la vista client_visible_tasks), ni editarla, ni borrarla.

drop policy if exists "client insert own task" on public.tasks;
create policy "client insert own task" on public.tasks
  for insert with check (
    client_id = public.current_client_id()
    and editor_id is null
    and price_per_video = 0
    and videos_done = 0
    and paid = false
    and workflow_status = 'Sin editar'
  );
