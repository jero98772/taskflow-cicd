from app import crud, schemas
from app.config import Settings
from app.database import make_engine


def test_settings_from_env(monkeypatch):
    monkeypatch.setenv("APP_VERSION", "1.2.3")
    monkeypatch.setenv("APP_COLOR", "green")
    monkeypatch.setenv("APP_ENV", "staging")
    s = Settings()
    assert (s.app_version, s.app_color, s.environment) == ("1.2.3", "green", "staging")


def test_make_engine_sqlite():
    assert make_engine("sqlite://").dialect.name == "sqlite"


def test_compute_stats_empty():
    s = crud.compute_stats([])
    assert s.total == 0 and s.completion_rate == 0.0


def test_crud_roundtrip(db_session):
    t = crud.create_task(db_session, schemas.TaskCreate(title="x"))
    crud.update_task(db_session, t, schemas.TaskUpdate(done=True))
    assert crud.list_tasks(db_session, done=True)[0].id == t.id
    crud.delete_task(db_session, t)
    assert crud.get_task(db_session, t.id) is None
