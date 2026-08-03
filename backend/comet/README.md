# Comet (Zipx debrid backend)

Gets **new releases** (4K/1080p, ad-free, direct files) into the native player
by scraping torrents + resolving them through **Real-Debrid**. The RD token
stays on the VPS (proxied streaming), never in the app.

## Before you start
1. **Regenerate** your Real-Debrid token at <https://real-debrid.com/apitoken>
   (the one pasted in chat must be rotated). Keep the new one for `.env` only.

## Deploy
```bash
cd ~/Zipx-Apk && git pull
cd backend/comet

cp .env.example .env
# put your NEW Real-Debrid token + two random passwords in .env:
nano .env          # or: sed -i "s/change-me-random/$(openssl rand -hex 16)/g" .env

docker compose up -d
docker compose ps
```

Open **TCP 8000** in hPanel -> VPS -> Firewall.

## Configure Real-Debrid
Open `http://<VPS_IP>:8000/configure` in a browser, choose **Real-Debrid**,
and copy the generated **install/stream URL**. That URL contains a `/<config>/`
segment - that's what the app calls:

```
http://<VPS_IP>:8000/<config>/stream/movie/<imdb_id>.json
http://<VPS_IP>:8000/<config>/stream/series/<imdb_id>:<season>:<episode>.json
```

The response is a JSON list of streams; each has a direct (Comet-proxied) `url`
the native player can play, with quality/size in the title.

> If the `<config>` string contains your RD token, do NOT paste it to me - the
> server-side default key means we can keep the token out of it. We'll sort the
> exact endpoint together once it's running.

## Update
```bash
cd ~/Zipx-Apk/backend/comet && docker compose pull && docker compose up -d
```
(The daily `backend/update.sh` can be extended to include this too.)
