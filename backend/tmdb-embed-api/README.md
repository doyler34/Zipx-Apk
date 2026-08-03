# TMDB-Embed-API (Zipx "sources" backend)

Give it a **TMDB id**, it returns **direct playable streams** (mp4/m3u8) with
the headers each needs — already resolved from providers like VixSrc, Vidlink,
Videasy, Showbox, 4KHDHub. The app calls this, shows a quality/server picker,
and plays natively (and can download).

Runs on your Hostinger VPS next to MediaFlow. You deploy it; no secrets shared.

---

## Deploy

```bash
cd ~/Zipx-Apk/backend/tmdb-embed-api

# TMDB key (the app's own key is pre-filled in .env.example - fine to reuse)
cp .env.example .env

# start it
docker compose up -d
docker compose ps
```

## Test it (this is the real test - a live movie)

`550` is Fight Club. From the VPS:

```bash
curl -s "http://localhost:8787/api/streams/movie/550" | head -c 1500
```

You should get back a JSON array of streams, each like:

```json
{
  "title": "Fight Club - 1080p [VixSrc]",
  "url": "https://.../video.m3u8",
  "quality": "1080p",
  "provider": "vixsrc",
  "headers": { "User-Agent": "Mozilla/5.0", "Referer": "https://..." }
}
```

Those `url`s are what the app plays. If the array is non-empty with real
`url`s, the whole backend works end to end.

## Endpoints the app uses

```
GET /api/streams/movie/{tmdbId}
GET /api/streams/series/{tmdbId}?season={s}&episode={e}
```

Admin UI + config live on the same port (8787). Default admin user `admin`.

## Firewall

The app needs to reach **TCP 8787** (same as 8888 for MediaFlow): allow it in
**hPanel -> VPS -> Firewall**.

## Update

```bash
cd ~/Zipx-Apk/backend/tmdb-embed-api
docker compose pull && docker compose up -d
```

---

## How it fits with MediaFlow

TMDB-Embed-API already returns resolved streams (and has its own proxy), so for
most content it's all the app needs. MediaFlow (port 8888) stays as an optional
extra resolver for hosts this one doesn't cover. Start with this one.
