// SQLite persistence for preparation jobs (survives app + server restarts).
// Self-contained, matching the "SQLite, no separate DB container" style the
// Comet service already uses.

import Database from 'better-sqlite3';
import { randomUUID } from 'node:crypto';

const db = new Database(process.env.DB_PATH || 'data/prepare.db');
db.pragma('journal_mode = WAL');
db.exec(`
  CREATE TABLE IF NOT EXISTS jobs (
    id             TEXT PRIMARY KEY,
    tmdbId         TEXT NOT NULL,
    mediaType      TEXT NOT NULL,
    title          TEXT,
    season         INTEGER,
    episode        INTEGER,
    hash           TEXT NOT NULL,
    fileIdx        INTEGER,
    rdId           TEXT,
    status         TEXT NOT NULL,
    progress       INTEGER,
    speed          INTEGER,
    error          TEXT,
    needsSelection INTEGER NOT NULL DEFAULT 1,
    rdCheckedAt    INTEGER NOT NULL DEFAULT 0,
    createdAt      INTEGER NOT NULL,
    updatedAt      INTEGER NOT NULL
  );
  CREATE INDEX IF NOT EXISTS idx_jobs_dedup
    ON jobs (tmdbId, season, episode, hash, status);
`);

// Lightweight migration for a DB created before fileIdx existed.
const cols = db.prepare('PRAGMA table_info(jobs)').all().map((c) => c.name);
if (!cols.includes('fileIdx')) db.exec('ALTER TABLE jobs ADD COLUMN fileIdx INTEGER');

const now = () => Date.now();

export const Store = {
  // An in-flight/ready job for the same content + release, used to prevent
  // duplicate Real-Debrid downloads.
  findActiveDuplicate({ tmdbId, season, episode, hash }) {
    return db
      .prepare(
        `SELECT * FROM jobs
           WHERE tmdbId = ? AND ifnull(season,-1) = ? AND ifnull(episode,-1) = ? AND hash = ?
             AND status IN ('queued','downloading','ready')
           ORDER BY createdAt DESC LIMIT 1`,
      )
      .get(String(tmdbId), season ?? -1, episode ?? -1, hash);
  },

  create(job) {
    const id = randomUUID();
    const ts = now();
    db.prepare(
      `INSERT INTO jobs
        (id,tmdbId,mediaType,title,season,episode,hash,fileIdx,rdId,status,progress,speed,error,needsSelection,rdCheckedAt,createdAt,updatedAt)
       VALUES
        (@id,@tmdbId,@mediaType,@title,@season,@episode,@hash,@fileIdx,@rdId,@status,@progress,@speed,@error,@needsSelection,0,@createdAt,@updatedAt)`,
    ).run({
      id,
      fileIdx: null,
      rdId: null,
      status: 'queued',
      progress: null,
      speed: null,
      error: null,
      needsSelection: 1,
      createdAt: ts,
      updatedAt: ts,
      ...job,
    });
    return this.get(id);
  },

  get(id) {
    return db.prepare('SELECT * FROM jobs WHERE id = ?').get(id);
  },

  update(id, fields) {
    const cur = this.get(id);
    if (!cur) return null;
    const merged = { ...cur, ...fields, updatedAt: now() };
    db.prepare(
      `UPDATE jobs SET
         rdId=@rdId, status=@status, progress=@progress, speed=@speed, error=@error,
         needsSelection=@needsSelection, rdCheckedAt=@rdCheckedAt, updatedAt=@updatedAt
       WHERE id=@id`,
    ).run(merged);
    return this.get(id);
  },

  remove(id) {
    db.prepare('DELETE FROM jobs WHERE id = ?').run(id);
  },
};
