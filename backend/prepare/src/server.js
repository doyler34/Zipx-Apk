// ZipX preparation service.
//
// Submits an uncached release (identified by its torrent infohash) to TorBox,
// tracks the download, and exposes a small pollable job API to the app. The
// TorBox key stays server-side; the app only ever sees an internal job id + a
// mapped status. When a job is "ready" the app can play it via /play (which
// resolves the correct file's direct link on demand) or re-query AIOStreams.
//
// TorBox is the single debrid provider (via AIOStreams for cached playback, and
// here for uncached preparation). It downloads the whole torrent, so the file to
// play is chosen at play time - the app-side guard only ever submits single-file
// episode releases, never a whole season pack.

import express from 'express';
import { Store } from './store.js';
import { TorBox } from './torbox.js';
import { selectFile } from './select.js';

const app = express();
app.use(express.json({ limit: '16kb' }));

const API_KEY = process.env.PREPARE_API_KEY || '';
const HASH_RE = /^[a-fA-F0-9]{40}$/;
// Sanity bound for a torrent file index (season packs are dozens of files, not
// tens of thousands) - anything beyond this is treated as "no specific file".
const MAX_FILE_IDX = 10_000;
// Don't hammer TorBox: a job refreshes from TorBox at most this often, no matter
// how frequently the app polls GET /status.
const DEBRID_REFRESH_MS = 10_000;

// Health check is public; everything else needs the shared app key.
app.get('/health', (_req, res) => res.json({ ok: true }));

app.use((req, res, next) => {
  if (!API_KEY) return res.status(500).json({ error: 'server_misconfigured' });
  if (req.get('X-Api-Key') !== API_KEY) return res.status(401).json({ error: 'unauthorized' });
  next();
});

// TorBox download state -> app status. Relies on the download_finished flag for
// "ready" and keeps genuinely-stalled downloads as "downloading" (not failed),
// so a slow-but-alive torrent isn't abandoned.
function mapStatus(t) {
  if (!t) return 'queued';
  if (t.download_finished === true) return 'ready';
  const s = String(t.download_state || '').toLowerCase();
  if (s === 'completed' || s.includes('cached')) return 'ready';
  if (s.includes('error') || s.includes('failed') || s.includes('dead') || s.includes('virus') || s.includes('missing')) {
    return 'failed';
  }
  if (
    s.includes('download') || s.includes('upload') || s.includes('meta') ||
    s.includes('check') || s.includes('stall') ||
    (typeof t.progress === 'number' && t.progress > 0)
  ) {
    return 'downloading';
  }
  return 'queued';
}

// The public shape returned to the app. Only includes progress/speed when
// TorBox genuinely reported them - never fabricated.
function publicJob(j) {
  const out = { jobId: j.id, status: j.status };
  if (j.progress != null) out.progress = j.progress; // 0..100
  if (j.speed != null && j.speed > 0) out.speed = j.speed; // bytes/sec, from TorBox
  if (j.error) out.error = j.error;
  return out;
}

// Refresh a job from TorBox (rate-limited). No file selection here - TorBox
// downloads the whole torrent and the file is chosen at play time.
async function refresh(job) {
  if (job.status === 'ready' || job.status === 'failed') return job;
  if (!job.rdId) return job;
  if (Date.now() - (job.rdCheckedAt || 0) < DEBRID_REFRESH_MS) return job;

  let t;
  try {
    t = await TorBox.info(job.rdId);
  } catch (e) {
    if (e.status === 404) {
      return Store.update(job.id, { status: 'failed', error: 'torrent_removed', rdCheckedAt: Date.now() });
    }
    return job; // transient TorBox error - keep last known state
  }
  if (!t) {
    return Store.update(job.id, { status: 'failed', error: 'torrent_removed', rdCheckedAt: Date.now() });
  }

  const status = mapStatus(t);
  return Store.update(job.id, {
    status,
    progress: typeof t.progress === 'number' ? Math.round(t.progress * 100) : job.progress,
    speed: typeof t.download_speed === 'number' ? t.download_speed : null,
    error: status === 'failed' ? (t.download_state || 'failed') : null,
    rdCheckedAt: Date.now(),
  });
}

// POST /prepare - submit an uncached release for preparation.
app.post('/prepare', async (req, res) => {
  const { tmdbId, mediaType, title, season, episode, hash, fileIdx } = req.body || {};

  // Validate: only accept a real 40-hex infohash (we build the magnet
  // ourselves), so this can never be used as an open proxy for arbitrary URLs.
  if (!tmdbId || (mediaType !== 'movie' && mediaType !== 'tv') || !HASH_RE.test(String(hash || ''))) {
    return res.status(400).json({ error: 'invalid_request' });
  }
  if (mediaType === 'tv' && (!Number.isInteger(season) || !Number.isInteger(episode))) {
    return res.status(400).json({ error: 'invalid_episode' });
  }

  // fileIdx is optional. It must be an integer when present; a valid, in-range
  // (0..MAX_FILE_IDX) index is kept, while -1 or absurd values become null
  // ("no specific file") so selection falls back safely - never a hard reject
  // that would waste a valid hash.
  let idx = null;
  if (fileIdx !== undefined && fileIdx !== null) {
    if (!Number.isInteger(fileIdx)) return res.status(400).json({ error: 'invalid_fileIdx' });
    if (fileIdx >= 0 && fileIdx <= MAX_FILE_IDX) idx = fileIdx;
  }

  const norm = {
    tmdbId: String(tmdbId),
    mediaType,
    title: String(title || '').slice(0, 300),
    season: mediaType === 'tv' ? season : null,
    episode: mediaType === 'tv' ? episode : null,
    hash: String(hash).toLowerCase(),
    fileIdx: idx,
  };

  // Dedup: reuse an existing active job for the same content+release instead of
  // starting a second TorBox download.
  const dup = Store.findActiveDuplicate(norm);
  if (dup) return res.json({ jobId: dup.id, status: dup.status });

  let job = Store.create(norm);
  try {
    const added = await TorBox.addMagnet(job.hash);
    const tid = added.torrent_id ?? added.id ?? null;
    if (tid == null) {
      // No torrent id (e.g. the item was queued at the concurrency limit); mark
      // failed with a clear reason so the app can retry an alternate source.
      job = Store.update(job.id, { status: 'failed', error: 'tb_no_torrent_id' });
    } else {
      job = Store.update(job.id, { rdId: String(tid), status: 'queued', needsSelection: 0 });
    }
  } catch {
    job = Store.update(job.id, { status: 'failed', error: 'tb_add_failed' });
  }

  res.status(201).json({ jobId: job.id, status: job.status });
});

// GET /prepare/find - is this content already prepared on the shared account?
// Lets ANY app instance discover a ready job by content (not jobId), so cached
// titles play instantly for everyone without waiting on AIOStreams. Declared
// before the /:jobId routes so "find" isn't matched as a job id.
app.get('/prepare/find', (req, res) => {
  const { tmdbId, mediaType, season, episode } = req.query;
  if (!tmdbId || (mediaType !== 'movie' && mediaType !== 'tv')) {
    return res.status(400).json({ error: 'invalid_request' });
  }
  const job = Store.findByContent({
    tmdbId: String(tmdbId),
    mediaType,
    season: mediaType === 'tv' && season != null && season !== '' ? Number(season) : null,
    episode: mediaType === 'tv' && episode != null && episode !== '' ? Number(episode) : null,
  });
  if (!job) return res.status(404).json({ error: 'not_found' });
  res.json({ jobId: job.id, status: job.status });
});

// GET /prepare/:jobId/status - poll a job (refreshes from TorBox, rate-limited).
app.get('/prepare/:jobId/status', async (req, res) => {
  let job = Store.get(req.params.jobId);
  if (!job) return res.status(404).json({ error: 'not_found' });
  job = (await refresh(job)) || job;
  res.json(publicJob(job));
});

// GET /prepare/:jobId/play - resolve a ready job to a fresh, directly-playable
// URL. Picks the correct file (the requested episode for TV, the main video for
// a movie) and requests its TorBox link on demand (never stored). 409 if it
// isn't downloaded yet.
app.get('/prepare/:jobId/play', async (req, res) => {
  const job = Store.get(req.params.jobId);
  if (!job) return res.status(404).json({ error: 'not_found' });
  if (!job.rdId) return res.status(409).json({ error: 'not_ready' });
  try {
    const t = await TorBox.info(job.rdId);
    if (!t) return res.status(409).json({ error: 'not_ready' });
    if (t.download_finished !== true) {
      Store.update(job.id, { status: mapStatus(t), rdCheckedAt: Date.now() });
      return res.status(409).json({ error: 'not_ready', status: mapStatus(t) });
    }
    const files = Array.isArray(t.files) ? t.files : [];
    const sel = selectFile(files, job);
    if (sel.error) return res.status(409).json({ error: sel.error });
    const url = await TorBox.requestDl(job.rdId, sel.fileId);
    if (!url) return res.status(502).json({ error: 'requestdl_failed' });
    Store.update(job.id, { status: 'ready', rdCheckedAt: Date.now() });
    return res.json({ url });
  } catch {
    return res.status(502).json({ error: 'play_failed' });
  }
});

// DELETE /prepare/:jobId - cancel/remove a tracked job (and its TorBox download).
app.delete('/prepare/:jobId', async (req, res) => {
  const job = Store.get(req.params.jobId);
  if (!job) return res.status(404).json({ error: 'not_found' });
  if (job.rdId) {
    try { await TorBox.delete(job.rdId); } catch { /* already gone - fine */ }
  }
  Store.remove(job.id);
  res.json({ ok: true });
});

const PORT = process.env.PORT || 3020;
app.listen(PORT, () => console.log(`zipx-prepare listening on :${PORT}`));
