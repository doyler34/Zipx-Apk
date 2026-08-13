# ZipX preparation service (port 3020)

Turns an **uncached** release into a playable one. When AIOStreams has no cached
result for a title, the app can submit the best uncached release here; this
service adds it to TorBox, tracks the download, and exposes a small pollable job
API. The correct file (the requested episode for TV, the main video for a movie)
is resolved at play time.

The TorBox API key stays on the VPS (in `.env`) and is **never** returned to the
app. When a job is `ready`, the app either plays it via `/play` (which resolves
a fresh file link on demand) or re-queries AIOStreams — this service does not
store debrid playback URLs (they expire).

TorBox is the single debrid provider: AIOStreams uses it for cached playback,
and this service uses it for uncached preparation.

## Deploy

```bash
cd backend/prepare
cp .env.example .env    # fill in TORBOX_API_KEY + PREPARE_API_KEY
docker compose up -d --build
```

It builds from local source, so after a `git pull` re-run `docker compose up -d
--build` (the daily `backend/update.sh` only pulls third-party images and does
not touch this one).

Job state persists in `./data/prepare.db` (SQLite), so it survives restarts.

## Auth

Every request except `GET /health` must send the shared secret:

```
X-Api-Key: <PREPARE_API_KEY>
```

Only a valid 40-hex torrent infohash is accepted — the magnet is built
server-side, so this can never be used as an open proxy for arbitrary URLs.

## API

### `POST /prepare`

Request:

```json
{
  "tmdbId": "550",
  "mediaType": "movie",         // "movie" | "tv"
  "title": "Fight Club",
  "season": 2,                   // tv only
  "episode": 7,                  // tv only
  "hash": "<40-hex infohash>",
  "fileIdx": 4                   // optional: AIOStreams' file index (0-based)
}
```

`fileIdx` is optional. When it's a valid, in-range index that lands on a real
video file, that exact file is played back. `-1`, out-of-range, or a
sample/extras/non-video target is ignored and selection falls back to the logic
below. A non-integer `fileIdx` is rejected (`400 invalid_fileIdx`).

Response `201`:

```json
{ "jobId": "b0c1…", "status": "queued" }
```

If an active job already exists for the same `tmdbId + season + episode + hash`,
the existing job is returned instead of starting a second download.

### `GET /prepare/{jobId}/status`

```json
{
  "jobId": "b0c1…",
  "status": "queued|downloading|ready|failed",
  "progress": 63,          // 0..100, only when TorBox reports it
  "speed": 5242880,        // bytes/sec, only when TorBox reports it
  "error": "error"         // only when failed
}
```

Refreshes from TorBox at most once every 10s per job, regardless of how often
the app polls.

### `GET /prepare/find?tmdbId=&mediaType=&season=&episode=`

Is this content already prepared on the shared account? Looks a job up by
**content** (not jobId), preferring a ready one, so any app instance can
discover a title someone else prepared and play it instantly. `404` if none.

```json
{ "jobId": "b0c1…", "status": "ready" }
```

### `GET /prepare/{jobId}/play`

Resolves the prepared file to a **fresh, directly-playable URL** on demand so a
ready item plays immediately (no waiting for AIOStreams' cached view). The right
file is picked (episode for TV, main video for a movie) and its TorBox link is
requested each time; the URL is never stored. `409` if the job isn't downloaded
yet.

```json
{ "url": "https://<torbox-host>/…" }
```

### `DELETE /prepare/{jobId}`

Cancels/removes the job and deletes the torrent from TorBox. Returns
`{ "ok": true }`.

## TorBox status mapping

| TorBox `download_state` (or `download_finished`)          | App status    |
| --------------------------------------------------------- | ------------- |
| `download_finished: true`, `completed`, `cached`          | `ready`       |
| `downloading`, `uploading`, `metaDL`, checking, `stalled` | `downloading` |
| (queued / not yet started)                                | `queued`      |
| `error`, `failed`, `dead`, `virus`, `missing`             | `failed`      |

`progress` is TorBox's 0..1 value scaled to 0..100; `speed` is `download_speed`
(bytes/sec) passed through unchanged.

## File selection

TorBox downloads the whole torrent, so the file is chosen when `/play` is
called (not at add time):

1. **Preferred — AIOStreams file index:** when `fileIdx` is valid, that exact
   file is used (TorBox file ids are 0-based in torrent order, so `id === fileIdx`,
   with a positional fallback). The target must be a real video file (not a
   sample/extra), or this is skipped.
2. **Fallback (index missing / -1 / out of range / wrong target):**
   - **Movie:** the largest video file, after dropping obvious `sample`/extras.
   - **TV:** the file whose name matches the requested `SxxEyy` (also `2x07` and
     a bare `Eyy`). A single-video torrent is taken as the episode. If the pack
     has multiple files and none can be identified as the requested episode, the
     job **fails safely** (`episode_not_identified`).

> The app only ever submits **single-file** episode releases for TV (never a
> whole season pack), so a TV job's torrent is just that episode.
