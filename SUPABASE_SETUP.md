# Poner el panel en producción con Supabase

`panel-interno.html` sigue siendo un único archivo estático — sin build, sin
Node, sin backend propio — pero ahora habla directo con una base de datos
real en Supabase (Postgres + Auth), protegida por Row Level Security (RLS)
en vez de por el `window.storage` que solo existía dentro de Claude.ai.

El login no usa contraseña: cada persona pone su email y recibe un **código
de 6 dígitos** por correo (Supabase Auth OTP). Esto evita necesitar una
`service_role key` o cualquier backend adicional para crear cuentas — algo
que un archivo HTML suelto no puede guardar de forma segura.

## 1. Crear el proyecto en Supabase

1. Andá a [supabase.com](https://supabase.com) y creá una cuenta / proyecto
   nuevo (plan gratuito). Elegí una contraseña de base de datos y guardala
   en un lugar seguro (no la vas a necesitar para este panel, pero sí si
   más adelante te conectás por otra vía).
2. Esperá a que el proyecto termine de aprovisionarse (1-2 minutos).

## 2. Cargar el esquema

1. En el dashboard del proyecto, abrí **SQL Editor** → **New query**.
2. Pegá el contenido completo de [`supabase/schema.sql`](supabase/schema.sql)
   de este repo.
3. Antes de ejecutar, revisá el bloque `ADMIN INICIAL`: tiene precargado
   `cresporafaelagustin@gmail.com` como el primer administrador. Si ese no
   es el email con el que vas a entrar, cambialo (o agregá otra fila igual
   con `insert into public.admin_emails (email) values ('otro@email.com');`
   después).
4. Ejecutá el script (▶ Run). Deberías ver "Success. No rows returned".

## 3. Configurar el login por email

1. En el dashboard, andá a **Authentication → Providers** y confirmá que
   **Email** esté habilitado (viene así por defecto).
2. En **Authentication → Email Templates**, la plantilla "Magic Link" ya
   incluye el código de 6 dígitos (`{{ .Token }}`) que este panel usa — no
   hace falta tocar nada, pero podés personalizar el texto del mail si
   querés que diga "SCA" en vez del texto genérico de Supabase.
3. En **Authentication → URL Configuration**, no hace falta configurar
   redirect URLs porque el panel usa el código de 6 dígitos (no el enlace
   mágico), así que funciona igual sin importar dónde lo hostees.

## 4. Conectar el panel

1. En el dashboard, andá a **Project Settings → API**.
2. Copiá el **Project URL** y el **anon public key**.
3. Abrí `panel-interno.html` en este repo y, cerca del principio del
   `<script>`, completá:
   ```js
   const SUPABASE_URL = 'https://TU-PROYECTO.supabase.co';
   const SUPABASE_ANON_KEY = 'ey...'; // el anon public key
   ```
4. El `anon key` es seguro de publicar tal cual (es la clave pública
   pensada para usarse desde el navegador) — quien de verdad protege los
   datos es Row Level Security, ya configurado en el paso 2. **Nunca**
   pongas la `service_role key` en este archivo: esa sí es secreta y le
   da acceso total sin pasar por RLS.
5. Subí el archivo a donde lo estés sirviendo (GitHub Pages, Netlify,
   donde sea) o abrilo local para probar.

## 5. Primer ingreso como administrador

1. Abrí el panel, poné tu email (el mismo que quedó en `admin_emails`) y
   tocá "Enviar código de acceso".
2. Revisá tu correo (puede tardar uno o dos minutos, y a veces cae en
   spam) y escribí el código de 6 dígitos.
3. Vas a entrar como Administrador automáticamente — eso lo decide el
   trigger `handle_new_user` en `schema.sql`, no algo que configures acá.

## 6. Agregar editores

Desde la pestaña **Editores → + Nuevo editor**, cargá nombre y (opcional
pero recomendado) el email de cada editor. Con ese email, cuando esa
persona entre al panel por primera vez con su propio código, va a quedar
vinculada automáticamente a su fila de editor gracias al mismo trigger.

Si un editor ya había entrado antes de que le cargaras el email (por
ejemplo probando el panel), el panel también hace el enlace retroactivo en
el momento en que guardás su email desde el modal de edición.

## 7. Cargar los datos del panel viejo

Si tenés el `.json` que bajaste con "Exportar datos" del panel anterior
(o de una versión previa de este mismo panel):

1. Entrá como administrador.
2. Arriba a la derecha, tocá **Importar backup**.
3. Elegí el archivo `.json` y confirmá.

Editores y clientes se emparejan por nombre (si ya existen, no se
duplican); las tareas siempre se crean como nuevas. Los editores
importados así no tienen email todavía (el export viejo no lo guardaba) —
editalos después para agregarles uno y que puedan loguearse.

## 8. Envío real de alertas (opcional, no incluido)

La pestaña **Alertas** arma el mensaje de cada tarea atrasada y abre un
`mailto:` o `wa.me` para mandarlo con un clic — igual que en el panel
original. Automatizar el envío (sin el clic) requeriría un servicio como
Resend/SendGrid para email y Twilio para WhatsApp/SMS disparado por un cron
o una Supabase Edge Function — no está armado en esta vuelta porque
implica dar de alta cuentas externas; avisame si querés que lo sumemos.

## Qué cambió respecto al brief original

- El modelo de datos es el mismo (`editors`, `clients`, `tasks`,
  `notify-settings`), solo que ahora vive en tablas reales de Postgres en
  vez de en `window.storage`.
- La autenticación es real (Supabase Auth), pero **passwordless por
  código de email** en vez de "email + contraseña" — así el archivo sigue
  sin necesitar un backend propio ni una service-role key para crear
  cuentas. Si en algún momento preferís contraseñas tradicionales, se
  puede migrar a `supabase.auth.signUp`/`resetPasswordForEmail`, pero
  agrega pasos de configuración extra en Supabase Auth.
- `editors` sumó una columna `email` (no existía en el modelo viejo) para
  poder vincular cada login con su editor.
