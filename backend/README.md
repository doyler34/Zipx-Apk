# Zipx backend (VPS)

Small Docker services power native, ad-free playback. The phone app only talks
to these over HTTP; all scraping/resolving lives here, so updating them never
requires updating the app.

- **`comet/`** (port 8000) - Real-Debrid source: new releases as direct,
  high-quality streams. The app's top source.
- **`tmdb-embed-api/`** (port 8787) - free-scraper source (VixSrc/Vidlink/
  NoTorrent/...), used when Real-Debrid has nothing.

The app queries Comet first, then TMDB-Embed-API, then falls back to the
in-app WebView providers (VidSrc etc.).

See each folder's README to deploy.

## Keeping the scrapers current (daily auto-update)

The scraping logic is maintained upstream and shipped as new Docker images.
`update.sh` pulls the latest images and restarts both services. Set it to run
daily with cron:

```bash
chmod +x /root/Zipx-Apk/backend/update.sh

# add a daily 4am job (edit the path if your clone lives elsewhere)
( crontab -l 2>/dev/null; \
  echo "0 4 * * * /root/Zipx-Apk/backend/update.sh >> /root/zipx-backend-update.log 2>&1" ) \
  | crontab -

# verify it's installed
crontab -l
```

Run it once by hand to confirm it works:

```bash
/root/Zipx-Apk/backend/update.sh
```

Logs land in `/root/zipx-backend-update.log`.

> The app does **not** need updating when these update - it's a thin client
> that just plays whatever URLs the backend returns.
