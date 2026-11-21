"""Lógica de negocio separada de la capa HTTP para facilitar pruebas unitarias."""

from sqlalchemy import select
from sqlalchemy.orm import Session

from . import models, schemas


def list_tasks(db: Session, done: bool | None = None) -> list[models.Task]:
    stmt = select(models.Task).order_by(models.Task.id)
    if done is not None:
        stmt = stmt.where(models.Task.done == done)
    return list(db.scalars(stmt))


def get_task(db: Session, task_id: int) -> models.Task | None:
    return db.get(models.Task, task_id)


def create_task(db: Session, data: schemas.TaskCreate) -> models.Task:
    task = models.Task(**data.model_dump())
    db.add(task)
    db.commit()
    db.refresh(task)
    return task


def update_task(db: Session, task: models.Task, data: schemas.TaskUpdate) -> models.Task:
    for field, value in data.model_dump(exclude_unset=True).items():
        setattr(task, field, value)
    db.commit()
    db.refresh(task)
    return task


def delete_task(db: Session, task: models.Task) -> None:
    db.delete(task)
    db.commit()


def compute_stats(tasks: list[models.Task]) -> schemas.Stats:
    total = len(tasks)
    done = sum(1 for t in tasks if t.done)
    rate = round(done / total * 100, 2) if total else 0.0
    return schemas.Stats(total=total, done=done, pending=total - done, completion_rate=rate)
