# ZipX preparation service (port 3020)

Turns an **uncached** release into a playable one. When AIOStreams has no cached
result for a title, the app can submit the best uncached release here; this
service adds it to Real-Debrid, selects the right file (the requested episode
for TV), tracks the download, and exposes a small pollable job API.

The Real-Debrid token stays on the VPS (in `.env`) and is **never** returned to
the app. When a job is `ready`, the app re-queries AIOStreams for a fresh
playback URL — this service does not store or hand back debrid playback URLs
(they expire).

## Deploy

```bash
cd backend/prepare
cp .env.example .env    # fill in RD_API_KEY + PREPARE_API_KEY
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
video file, that exact file is selected. `-1`, out-of-range, or a
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
  "progress": 63,          // only when RD reports it
  "speed": 5242880,        // bytes/sec, only when RD reports it
  "error": "dead"          // only when failed
}
```

Refreshes from Real-Debrid at most once every 10s per job, regardless of how
often the app polls.

### `GET /prepare/{jobId}/play`

Unrestricts the prepared file to a **fresh, directly-playable URL** on demand so
a ready item plays immediately (no waiting for AIOStreams' cached view). The URL
is never stored (RD `download` links are temporary). `409` if the job isn't
downloaded yet.

```json
{ "url": "https://<rd-host>/d/…" }
```

### `DELETE /prepare/{jobId}`

Cancels/removes the job and deletes the torrent from Real-Debrid. Returns
`{ "ok": true }`.

## Real-Debrid status mapping

| Real-Debrid status                                   | App status    |
| ---------------------------------------------------- | ------------- |
| `magnet_conversion`, `waiting_files_selection`, `queued` | `queued`      |
| `downloading`, `compressing`, `uploading`            | `downloading` |
| `downloaded`                                         | `ready`       |
| `magnet_error`, `error`, `virus`, `dead`             | `failed`      |

## File selection

1. **Preferred — AIOStreams file index:** when `fileIdx` is valid, the exact
   file is selected (Real-Debrid file ids are 1-based in torrent order, so
   `id === fileIdx + 1`). The target must be a real video file (not a
   sample/extra), or this is skipped.
2. **Fallback (index missing / -1 / out of range / wrong target):**
   - **Movie:** the largest video file, after dropping obvious `sample`/extras.
   - **TV:** the file whose name matches the requested `SxxEyy` (also `2x07` and
     a bare `Eyy`). A single-video torrent is taken as the episode. If the pack
     has multiple files and none can be identified as the requested episode, the
     job **fails safely** (`episode_not_identified`) rather than downloading the
     whole season.
