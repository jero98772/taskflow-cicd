// Prueba de carga ligera pre-producción (k6): valida latencia y tasa de error bajo carga.
import http from "k6/http";
import { check, sleep } from "k6";

const BASE = __ENV.BASE_URL || "http://localhost:8080";

export const options = {
  vus: 10,
  duration: "20s",
  thresholds: {
    http_req_failed: ["rate<0.01"],    // < 1% de errores
    http_req_duration: ["p(95)<500"],  // p95 < 500 ms
  },
};

export default function () {
  check(http.get(`${BASE}/api/tasks`), { "list 200": (r) => r.status === 200 });
  check(http.get(`${BASE}/api/tasks/stats`), { "stats 200": (r) => r.status === 200 });
  check(http.get(`${BASE}/`), { "frontend 200": (r) => r.status === 200 });
  sleep(0.5);
}
