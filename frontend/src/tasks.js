// Lógica pura (sin DOM) para poder probarla con node --test.
export const PRIORITY_ORDER = { high: 0, medium: 1, low: 2 };

export function sortTasks(tasks) {
  return [...tasks].sort((a, b) => {
    if (a.done !== b.done) return a.done ? 1 : -1;
    const p = PRIORITY_ORDER[a.priority] - PRIORITY_ORDER[b.priority];
    return p !== 0 ? p : a.id - b.id;
  });
}

export function filterTasks(tasks, filter) {
  if (filter === "done") return tasks.filter((t) => t.done);
  if (filter === "pending") return tasks.filter((t) => !t.done);
  return tasks;
}

export function validateTitle(title) {
  const t = (title ?? "").trim();
  if (!t) return "El título es obligatorio";
  if (t.length > 200) return "Máximo 200 caracteres";
  return null;
}

export function escapeHtml(s) {
  return String(s)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}

export function progressLabel(stats) {
  return `${stats.done}/${stats.total} completadas (${stats.completion_rate}%)`;
}
