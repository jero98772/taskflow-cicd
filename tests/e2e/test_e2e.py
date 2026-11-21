"""Pruebas de integración E2E pre-producción contra el ambiente staging desplegado.

Recorren el sistema completo:
navegador -> Nginx (frontend) -> Service api (blue/green) -> SQLite (PVC).
Uso: BASE_URL=http://localhost:8080 EXPECTED_VERSION=1.2.0 pytest tests/e2e
"""

import os
import uuid

import httpx
import pytest

BASE_URL = os.getenv("BASE_URL", "http://localhost:8080")
EXPECTED_VERSION = os.getenv("EXPECTED_VERSION")


@pytest.fixture(scope="module")
def http():
    with httpx.Client(base_url=BASE_URL, timeout=10) as c:
        yield c


def test_frontend_serves_spa_and_assets(http):
    r = http.get("/")
    assert r.status_code == 200 and "TaskFlow" in r.text
    assert http.get("/app.js").status_code == 200
    assert http.get("/tasks.js").status_code == 200
    assert http.get("/styles.css").status_code == 200


def test_gateway_routes_to_api(http):
    assert http.get("/health").json() == {"status": "ok"}


def test_deployed_version_and_environment(http):
    v = http.get("/version").json()
    assert v["environment"] == "staging"
    assert v["color"] in {"blue", "green"}
    if EXPECTED_VERSION:
        assert v["version"] == EXPECTED_VERSION


def test_full_task_lifecycle(http):
    title = f"e2e-{uuid.uuid4().hex[:8]}"
    created = http.post("/api/tasks", json={"title": title, "priority": "high"})
    assert created.status_code == 201
    tid = created.json()["id"]

    assert any(t["id"] == tid for t in http.get("/api/tasks").json())

    upd = http.patch(f"/api/tasks/{tid}", json={"done": True})
    assert upd.json()["done"] is True
    assert any(t["id"] == tid for t in http.get("/api/tasks", params={"done": True}).json())

    assert http.delete(f"/api/tasks/{tid}").status_code == 204
    assert http.get(f"/api/tasks/{tid}").status_code == 404


def test_validation_errors_propagate_through_gateway(http):
    assert http.post("/api/tasks", json={"title": ""}).status_code == 422
    assert http.post("/api/tasks", json={"title": "x", "priority": "bad"}).status_code == 422


def test_stats_consistency(http):
    s = http.get("/api/tasks/stats").json()
    assert s["total"] == s["done"] + s["pending"]
    assert 0 <= s["completion_rate"] <= 100


def test_spa_fallback_routes_unknown_paths_to_index(http):
    r = http.get("/ruta/que/no/existe")
    assert r.status_code == 200 and "TaskFlow" in r.text
