from __future__ import annotations

import json
import sqlite3
from typing import Any

from sqlalchemy import Column, MetaData, String, Table, Text, create_engine, insert, select, update


STATE_KEY = "backend_state"


class SQLiteStateStore:
    def __init__(self, database_path: str):
        self.database_path = database_path
        self._ensure_schema()

    def load(self) -> dict[str, Any] | None:
        with sqlite3.connect(self.database_path) as connection:
            row = connection.execute("select value from state where key = ?", (STATE_KEY,)).fetchone()
        if not row:
            return None
        return json.loads(row[0])

    def save(self, snapshot: dict[str, Any]) -> None:
        with sqlite3.connect(self.database_path) as connection:
            connection.execute(
                """
                insert into state(key, value) values(?, ?)
                on conflict(key) do update set value = excluded.value
                """,
                (STATE_KEY, json.dumps(snapshot, separators=(",", ":"))),
            )

    def _ensure_schema(self) -> None:
        with sqlite3.connect(self.database_path) as connection:
            connection.execute(
                """
                create table if not exists state(
                    key text primary key,
                    value text not null
                )
                """
            )


class SQLAlchemyStateStore:
    def __init__(self, database_url: str):
        self.database_url = database_url
        self.engine = create_engine(database_url, future=True)
        self.metadata = MetaData()
        self.state = Table(
            "state",
            self.metadata,
            Column("key", String(128), primary_key=True),
            Column("value", Text, nullable=False),
        )

    def load(self) -> dict[str, Any] | None:
        self._ensure_schema()
        with self.engine.begin() as connection:
            row = connection.execute(select(self.state.c.value).where(self.state.c.key == STATE_KEY)).first()
        if not row:
            return None
        return json.loads(row[0])

    def save(self, snapshot: dict[str, Any]) -> None:
        self._ensure_schema()
        value = json.dumps(snapshot, separators=(",", ":"))
        with self.engine.begin() as connection:
            result = connection.execute(
                update(self.state)
                .where(self.state.c.key == STATE_KEY)
                .values(value=value)
            )
            if result.rowcount == 0:
                connection.execute(insert(self.state).values(key=STATE_KEY, value=value))

    def _ensure_schema(self) -> None:
        self.metadata.create_all(self.engine)
