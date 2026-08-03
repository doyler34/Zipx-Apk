# Zipx backend (VPS)

Two small Docker services power native, ad-free playback. The phone app only
talks to these over HTTP; all scraping/resolving lives here, so updating them
never requires updating the app.

- **`tmdb-embed-api/`** (port 8787) - the main "sources" service: TMDB id ->
  direct playable streams (m3u8/mp4). This is what the app calls.
- **`mediaflow/`** (port 8888) - optional extra resolver for tricky hosts.

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
