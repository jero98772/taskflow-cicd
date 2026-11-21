import { test } from "node:test";
import assert from "node:assert/strict";
import {
  escapeHtml, filterTasks, progressLabel, sortTasks, validateTitle,
} from "../src/tasks.js";

const tasks = [
  { id: 1, priority: "low", done: false },
  { id: 2, priority: "high", done: true },
  { id: 3, priority: "high", done: false },
  { id: 4, priority: "medium", done: false },
];

test("sortTasks: pendientes primero y por prioridad", () => {
  assert.deepEqual(sortTasks(tasks).map((t) => t.id), [3, 4, 1, 2]);
});

test("sortTasks no muta el arreglo original", () => {
  const copy = [...tasks];
  sortTasks(tasks);
  assert.deepEqual(tasks, copy);
});

test("sortTasks desempata por id", () => {
  const t = [{ id: 9, priority: "low", done: false }, { id: 5, priority: "low", done: false }];
  assert.deepEqual(sortTasks(t).map((x) => x.id), [5, 9]);
});

test("filterTasks", () => {
  assert.equal(filterTasks(tasks, "all").length, 4);
  assert.deepEqual(filterTasks(tasks, "done").map((t) => t.id), [2]);
  assert.equal(filterTasks(tasks, "pending").length, 3);
});

test("validateTitle", () => {
  assert.equal(validateTitle("  "), "El título es obligatorio");
  assert.equal(validateTitle(undefined), "El título es obligatorio");
  assert.equal(validateTitle("x".repeat(201)), "Máximo 200 caracteres");
  assert.equal(validateTitle("ok"), null);
});

test("escapeHtml previene XSS", () => {
  assert.equal(escapeHtml(`<img src=x onerror='a'>&"`),
    "&lt;img src=x onerror=&#39;a&#39;&gt;&amp;&quot;");
});

test("progressLabel", () => {
  assert.equal(progressLabel({ done: 1, total: 2, completion_rate: 50 }), "1/2 completadas (50%)");
});
