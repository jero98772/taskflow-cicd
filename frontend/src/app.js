import { escapeHtml, filterTasks, progressLabel, sortTasks, validateTitle } from "./tasks.js";

const api = (path, opts = {}) =>
  fetch(`/api${path}`, { headers: { "Content-Type": "application/json" }, ...opts }).then((r) => {
    if (!r.ok) throw new Error(`HTTP ${r.status}`);
    return r.status === 204 ? null : r.json();
  });

let currentFilter = "all";
const $ = (id) => document.getElementById(id);

async function render() {
  const [tasks, stats] = await Promise.all([api("/tasks"), api("/tasks/stats")]);
  $("progress").textContent = progressLabel(stats);
  $("list").innerHTML = sortTasks(filterTasks(tasks, currentFilter))
    .map(
      (t) => `<li class="task ${t.done ? "done" : ""} p-${t.priority}" data-id="${t.id}">
        <input type="checkbox" ${t.done ? "checked" : ""} data-action="toggle">
        <span class="title">${escapeHtml(t.title)}</span>
        <span class="badge">${t.priority}</span>
        <button data-action="delete" aria-label="Eliminar">✕</button>
      </li>`,
    )
    .join("");
}

async function loadVersion() {
  try {
    const v = await fetch("/version").then((r) => r.json());
    $("version").textContent = `v${v.version} · ${v.environment} · ${v.color}`;
    $("version").className = `env ${v.color}`;
  } catch {
    $("version").textContent = "API no disponible";
  }
}

$("form").addEventListener("submit", async (e) => {
  e.preventDefault();
  const title = $("title").value;
  const err = validateTitle(title);
  $("error").textContent = err ?? "";
  if (err) return;
  await api("/tasks", {
    method: "POST",
    body: JSON.stringify({ title: title.trim(), priority: $("priority").value }),
  });
  $("title").value = "";
  render();
});

$("list").addEventListener("click", async (e) => {
  const action = e.target.dataset.action;
  if (!action) return;
  const li = e.target.closest("li");
  const id = li.dataset.id;
  if (action === "toggle") {
    await api(`/tasks/${id}`, {
      method: "PATCH",
      body: JSON.stringify({ done: e.target.checked }),
    });
  } else if (action === "delete") {
    await api(`/tasks/${id}`, { method: "DELETE" });
  }
  render();
});

document.querySelectorAll("[data-filter]").forEach((b) =>
  b.addEventListener("click", () => {
    currentFilter = b.dataset.filter;
    document.querySelectorAll("[data-filter]").forEach((x) => x.classList.remove("active"));
    b.classList.add("active");
    render();
  }),
);

loadVersion();
render();
