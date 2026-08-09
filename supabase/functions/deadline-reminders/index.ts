// Edge Function: deadline-reminders
//
// Revisa tareas incompletas cuya fecha de entrega cae dentro de 3, 2 o 1
// día(s) a partir de hoy, y le manda un email de aviso al editor asignado
// (usando su "notification_email" de la pestaña Mis proyecciones) a
// través de Resend. Marca cada aviso como enviado para no repetirlo.
//
// Pensada para dispararse una vez por día vía pg_cron — ver
// SUPABASE_SETUP.md, sección "Recordatorios de entrega".
//
// Variables de entorno que usa:
//   SUPABASE_URL              — inyectada automáticamente por Supabase
//   SUPABASE_SERVICE_ROLE_KEY — inyectada automáticamente por Supabase
//   RESEND_API_KEY            — la agregás vos como secret (ver guía)
//   REMINDER_FROM_EMAIL       — opcional; por defecto onboarding@resend.dev

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY")!;
const FROM_EMAIL = Deno.env.get("REMINDER_FROM_EMAIL") || "onboarding@resend.dev";

const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

function targetDateISO(offsetDays: number): string {
  const d = new Date();
  d.setUTCHours(0, 0, 0, 0);
  d.setUTCDate(d.getUTCDate() + offsetDays);
  return d.toISOString().slice(0, 10);
}

async function sendReminderEmail(to: string, subject: string, text: string) {
  const res = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${RESEND_API_KEY}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ from: FROM_EMAIL, to: [to], subject, text }),
  });
  if (!res.ok) {
    const body = await res.text();
    throw new Error(`Resend error ${res.status}: ${body}`);
  }
}

type ThresholdColumn = "reminder_sent_3d" | "reminder_sent_2d" | "reminder_sent_1d";
const THRESHOLDS: { days: number; column: ThresholdColumn }[] = [
  { days: 3, column: "reminder_sent_3d" },
  { days: 2, column: "reminder_sent_2d" },
  { days: 1, column: "reminder_sent_1d" },
];

Deno.serve(async (_req) => {
  const results: Array<Record<string, unknown>> = [];

  for (const { days, column } of THRESHOLDS) {
    const deadline = targetDateISO(days);

    const { data: tasks, error } = await supabase
      .from("tasks")
      .select("id, project, deadline, video_count, videos_done, editor_id, editors:editor_id(name, notification_email)")
      .eq("deadline", deadline)
      .eq(column, false);

    if (error) {
      results.push({ days, error: error.message });
      continue;
    }

    for (const task of tasks || []) {
      const editor = (task as Record<string, any>).editors;
      const notificationEmail = editor?.notification_email;
      if (!notificationEmail) continue; // no cargó email de aviso todavía

      const videoCount = Number(task.video_count) || 0;
      const videosDone = Number(task.videos_done) || 0;
      if (videosDone >= videoCount) continue; // ya está completa

      try {
        const remaining = Math.max(videoCount - videosDone, 0);
        await sendReminderEmail(
          notificationEmail,
          `Recordatorio: "${task.project}" vence en ${days} día${days === 1 ? "" : "s"}`,
          `Hola ${editor?.name || ""},\n\n` +
            `Tu tarea "${task.project}" vence el ${task.deadline} (en ${days} día${days === 1 ? "" : "s"}). ` +
            `Te faltan ${remaining} video${remaining === 1 ? "" : "s"} por completar.\n\n— Panel SCA`,
        );
        await supabase.from("tasks").update({ [column]: true }).eq("id", task.id);
        results.push({ taskId: task.id, days, sent: true });
      } catch (e) {
        results.push({ taskId: task.id, days, sent: false, error: String(e) });
      }
    }
  }

  return new Response(JSON.stringify({ ok: true, results }), {
    headers: { "Content-Type": "application/json" },
  });
});
