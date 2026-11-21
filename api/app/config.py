"""Configuración leída desde variables de entorno (12-factor)."""

import os


class Settings:
    def __init__(self) -> None:
        self.app_version: str = os.getenv("APP_VERSION", "0.0.0-dev")
        self.app_color: str = os.getenv("APP_COLOR", "blue")
        self.environment: str = os.getenv("APP_ENV", "local")
        self.database_url: str = os.getenv("DATABASE_URL", "sqlite:///./taskflow.db")


settings = Settings()
