-- CHRONA SQLite schema snapshot
-- Source: lib/database/app_database.dart
-- Current application database version: 7

CREATE TABLE IF NOT EXISTS task (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    title TEXT NOT NULL,
    note TEXT,
    completed INTEGER NOT NULL DEFAULT 0,
    created_at INTEGER NOT NULL,
    completed_at INTEGER,
    duration_seconds INTEGER NOT NULL DEFAULT 900,
    plan_date INTEGER NOT NULL,
    sort_order INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS focus_session (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    task_id INTEGER,
    task_title_snapshot TEXT NOT NULL,
    started_at INTEGER NOT NULL,
    ended_at INTEGER NOT NULL,
    planned_duration_seconds INTEGER NOT NULL,
    actual_duration_seconds INTEGER NOT NULL,
    note TEXT,
    status TEXT NOT NULL,
    created_at INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS journal_entry (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    entry_date TEXT NOT NULL UNIQUE,
    question_id INTEGER,
    question_text TEXT,
    question_answer TEXT,
    content TEXT,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL
);

-- There are currently no database-level foreign keys or indexes beyond
-- the primary-key and UNIQUE constraints declared above.
