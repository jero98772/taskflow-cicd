from contextlib import asynccontextmanager

from fastapi import Depends, FastAPI, HTTPException, Response, status
from sqlalchemy import text
from sqlalchemy.orm import Session

from . import crud, schemas
from .config import settings
from .database import Base, engine, get_db


@asynccontextmanager
async def lifespan(_app: FastAPI):
    Base.metadata.create_all(bind=engine)
    yield


app = FastAPI(title="TaskFlow API", version=settings.app_version, lifespan=lifespan)


@app.get("/health")
def health(db: Session = Depends(get_db)):
    db.execute(text("SELECT 1"))
    return {"status": "ok"}


@app.get("/version")
def version():
    return {
        "version": settings.app_version,
        "color": settings.app_color,
        "environment": settings.environment,
    }


@app.get("/api/tasks", response_model=list[schemas.TaskOut])
def list_tasks(done: bool | None = None, db: Session = Depends(get_db)):
    return crud.list_tasks(db, done)


@app.get("/api/tasks/stats", response_model=schemas.Stats)
def stats(db: Session = Depends(get_db)):
    return crud.compute_stats(crud.list_tasks(db))


@app.post("/api/tasks", response_model=schemas.TaskOut, status_code=status.HTTP_201_CREATED)
def create_task(data: schemas.TaskCreate, db: Session = Depends(get_db)):
    return crud.create_task(db, data)


def _get_or_404(db: Session, task_id: int):
    task = crud.get_task(db, task_id)
    if task is None:
        raise HTTPException(status_code=404, detail="Task not found")
    return task


@app.get("/api/tasks/{task_id}", response_model=schemas.TaskOut)
def get_task(task_id: int, db: Session = Depends(get_db)):
    return _get_or_404(db, task_id)


@app.patch("/api/tasks/{task_id}", response_model=schemas.TaskOut)
def update_task(task_id: int, data: schemas.TaskUpdate, db: Session = Depends(get_db)):
    return crud.update_task(db, _get_or_404(db, task_id), data)


@app.delete("/api/tasks/{task_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_task(task_id: int, db: Session = Depends(get_db)):
    crud.delete_task(db, _get_or_404(db, task_id))
    return Response(status_code=status.HTTP_204_NO_CONTENT)
