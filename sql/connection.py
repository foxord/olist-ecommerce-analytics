"""Строка подключения для скриптов и ноутбуков проекта."""
import os
from pathlib import Path


def database_url(root=None):
    if os.environ.get("DATABASE_URL"):
        return os.environ["DATABASE_URL"]
    project = Path(root) if root else Path(__file__).resolve().parents[1]
    env_file = project / ".env"
    if env_file.exists():
        for line in env_file.read_text(encoding="utf-8-sig").splitlines():
            key, _, value = line.partition("=")
            if key.strip() == "DATABASE_URL":
                return value.strip().strip("'").strip('"')
    return "postgresql://localhost/olist"
