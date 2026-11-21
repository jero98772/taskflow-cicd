def _create(client, **kw):
    payload = {"title": "Tarea", **kw}
    r = client.post("/api/tasks", json=payload)
    assert r.status_code == 201, r.text
    return r.json()


def test_health(client):
    r = client.get("/health")
    assert r.status_code == 200
    assert r.json() == {"status": "ok"}


def test_version_exposes_color_and_env(client):
    body = client.get("/version").json()
    assert set(body) == {"version", "color", "environment"}


def test_create_and_get(client):
    t = _create(client, title="Escribir pipeline", priority="high")
    assert t["done"] is False and t["priority"] == "high"
    r = client.get(f"/api/tasks/{t['id']}")
    assert r.json()["title"] == "Escribir pipeline"


def test_create_validation_rejects_empty_title(client):
    assert client.post("/api/tasks", json={"title": ""}).status_code == 422


def test_create_validation_rejects_bad_priority(client):
    assert client.post("/api/tasks", json={"title": "x", "priority": "urgent"}).status_code == 422


def test_list_and_filter(client):
    a = _create(client, title="a")
    _create(client, title="b")
    client.patch(f"/api/tasks/{a['id']}", json={"done": True})
    assert len(client.get("/api/tasks").json()) == 2
    done = client.get("/api/tasks", params={"done": True}).json()
    assert [t["title"] for t in done] == ["a"]
    pending = client.get("/api/tasks", params={"done": False}).json()
    assert [t["title"] for t in pending] == ["b"]


def test_update_partial(client):
    t = _create(client, title="orig", description="d")
    r = client.patch(f"/api/tasks/{t['id']}", json={"title": "nuevo"})
    assert r.status_code == 200
    assert r.json()["title"] == "nuevo" and r.json()["description"] == "d"


def test_delete(client):
    t = _create(client)
    assert client.delete(f"/api/tasks/{t['id']}").status_code == 204
    assert client.get(f"/api/tasks/{t['id']}").status_code == 404


def test_not_found_paths(client):
    assert client.get("/api/tasks/999").status_code == 404
    assert client.patch("/api/tasks/999", json={"done": True}).status_code == 404
    assert client.delete("/api/tasks/999").status_code == 404


def test_stats(client):
    assert client.get("/api/tasks/stats").json()["completion_rate"] == 0.0
    a = _create(client, title="a")
    _create(client, title="b")
    client.patch(f"/api/tasks/{a['id']}", json={"done": True})
    s = client.get("/api/tasks/stats").json()
    assert s == {"total": 2, "done": 1, "pending": 1, "completion_rate": 50.0}
