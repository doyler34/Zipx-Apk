// ZipX preparation service.
//
// Submits an uncached release (identified by its torrent infohash) to
// Real-Debrid, selects the correct file (the requested episode for TV), tracks
// the download, and exposes a small pollable job API to the app. The RD token
// stays server-side; the app only ever sees an internal job id + a mapped
// status. When a job is "ready" the app re-queries AIOStreams for a fresh
// playback URL - this service never stores/returns a debrid playback URL.

import express from 'express';
import { Store } from './store.js';
import { RealDebrid } from './rd.js';
import { selectFiles } from './select.js';

const app = express();
app.use(express.json({ limit: '16kb' }));

const API_KEY = process.env.PREPARE_API_KEY || '';
const HASH_RE = /^[a-fA-F0-9]{40}$/;
// Sanity bound for a torrent file index (season packs are dozens of files, not
// tens of thousands) - anything beyond this is treated as "no specific file".
const MAX_FILE_IDX = 10_000;
// Don't hammer Real-Debrid: a job refreshes from RD at most this often, no
// matter how frequently the app polls GET /status.
const RD_REFRESH_MS = 10_000;

// Health check is public; everything else needs the shared app key.
app.get('/health', (_req, res) => res.json({ ok: true }));

app.use((req, res, next) => {
  if (!API_KEY) return res.status(500).json({ error: 'server_misconfigured' });
  if (req.get('X-Api-Key') !== API_KEY) return res.status(401).json({ error: 'unauthorized' });
  next();
});

// Real-Debrid status -> app status.
function mapStatus(rdStatus) {
  switch (rdStatus) {
    case 'magnet_conversion':
    case 'waiting_files_selection':
    case 'queued':
      return 'queued';
    case 'downloading':
    case 'compressing':
    case 'uploading':
      return 'downloading';
    case 'downloaded':
      return 'ready';
    case 'magnet_error':
    case 'error':
    case 'virus':
    case 'dead':
      return 'failed';
    default:
      return 'queued';
  }
}

// The public shape returned to the app. Only includes progress/speed when
// Real-Debrid genuinely reported them - never fabricated.
function publicJob(j) {
  const out = { jobId: j.id, status: j.status };
  if (j.progress != null) out.progress = j.progress;
  if (j.speed != null && j.speed > 0) {
    out.speed = j.speed; // bytes/sec, straight from RD
    if (j.status === 'downloading') {
      // ETA is derived from real RD values only (remaining bytes / speed); we
      // can't compute it without the byte total, so it's omitted when unknown.
    }
  }
  if (j.error) out.error = j.error;
  return out;
}

// Refresh a job from Real-Debrid (rate-limited) and lazily select the file once
// RD has listed the torrent's contents.
async function refresh(job) {
  if (job.status === 'ready' || job.status === 'failed') return job;
  if (!job.rdId) return job;
  if (Date.now() - (job.rdCheckedAt || 0) < RD_REFRESH_MS) return job;

  let info;
  try {
    info = await RealDebrid.info(job.rdId);
  } catch (e) {
    if (e.status === 404) {
      return Store.update(job.id, { status: 'failed', error: 'torrent_removed', rdCheckedAt: Date.now() });
    }
    return job; // transient RD error - keep last known state
  }

  // Lazy file selection: once RD lists the files, pick the right one.
  if (job.needsSelection && info.status === 'waiting_files_selection' &&
      Array.isArray(info.files) && info.files.length) {
    const sel = selectFiles(info.files, job);
    if (sel.error) {
      try { await RealDebrid.delete(job.rdId); } catch { /* ignore */ }
      return Store.update(job.id, { status: 'failed', error: sel.error, needsSelection: 0, rdCheckedAt: Date.now() });
    }
    try {
      await RealDebrid.selectFiles(job.rdId, sel.fileIds);
      Store.update(job.id, { needsSelection: 0 });
      info = await RealDebrid.info(job.rdId);
    } catch {
      return job; // try again next poll
    }
  }

  const status = mapStatus(info.status);
  return Store.update(job.id, {
    status,
    progress: typeof info.progress === 'number' ? Math.round(info.progress) : job.progress,
    speed: typeof info.speed === 'number' ? info.speed : null,
    error: status === 'failed' ? (info.status || 'failed') : null,
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
  // starting a second Real-Debrid download.
  const dup = Store.findActiveDuplicate(norm);
  if (dup) return res.json({ jobId: dup.id, status: dup.status });

  let job = Store.create(norm);
  try {
    const added = await RealDebrid.addMagnet(job.hash);
    job = Store.update(job.id, { rdId: added.id, status: 'queued' });

    // Best-effort immediate file selection; otherwise it happens on first poll.
    try {
      const info = await RealDebrid.info(added.id);
      if (info.status === 'waiting_files_selection' && Array.isArray(info.files) && info.files.length) {
        const sel = selectFiles(info.files, job);
        if (sel.error) {
          try { await RealDebrid.delete(added.id); } catch { /* ignore */ }
          job = Store.update(job.id, { status: 'failed', error: sel.error, needsSelection: 0 });
        } else {
          await RealDebrid.selectFiles(added.id, sel.fileIds);
          job = Store.update(job.id, { needsSelection: 0 });
        }
      }
    } catch { /* selection will retry on the first status poll */ }
  } catch {
    job = Store.update(job.id, { status: 'failed', error: 'rd_add_failed' });
  }

  res.status(201).json({ jobId: job.id, status: job.status });
});

// GET /prepare/:jobId/status - poll a job (refreshes from RD, rate-limited).
app.get('/prepare/:jobId/status', async (req, res) => {
  let job = Store.get(req.params.jobId);
  if (!job) return res.status(404).json({ error: 'not_found' });
  job = (await refresh(job)) || job;
  res.json(publicJob(job));
});

// GET /prepare/:jobId/play - resolve a ready job to a fresh, directly-playable
// URL. This unrestricts the exact prepared file on demand (never stores the
// URL), so a downloaded episode plays immediately without waiting for
// AIOStreams' cached view to catch up. 409 if it isn't downloaded yet.
app.get('/prepare/:jobId/play', async (req, res) => {
  const job = Store.get(req.params.jobId);
  if (!job) return res.status(404).json({ error: 'not_found' });
  if (!job.rdId) return res.status(409).json({ error: 'not_ready' });
  try {
    const info = await RealDebrid.info(job.rdId);
    if (info.status !== 'downloaded') {
      Store.update(job.id, { status: mapStatus(info.status), rdCheckedAt: Date.now() });
      return res.status(409).json({ error: 'not_ready', status: mapStatus(info.status) });
    }
    // We select exactly one file per job, so links[0] is that file.
    const links = Array.isArray(info.links) ? info.links : [];
    if (links.length === 0) return res.status(409).json({ error: 'no_link' });
    const un = await RealDebrid.unrestrict(links[0]);
    if (!un || !un.download) return res.status(502).json({ error: 'unrestrict_failed' });
    Store.update(job.id, { status: 'ready', rdCheckedAt: Date.now() });
    return res.json({ url: un.download });
  } catch {
    return res.status(502).json({ error: 'play_failed' });
  }
});

// DELETE /prepare/:jobId - cancel/remove a tracked job (and its RD download).
app.delete('/prepare/:jobId', async (req, res) => {
  const job = Store.get(req.params.jobId);
  if (!job) return res.status(404).json({ error: 'not_found' });
  if (job.rdId) {
    try { await RealDebrid.delete(job.rdId); } catch { /* already gone - fine */ }
  }
  Store.remove(job.id);
  res.json({ ok: true });
});

const PORT = process.env.PORT || 3020;
app.listen(PORT, () => console.log(`zipx-prepare listening on :${PORT}`));
