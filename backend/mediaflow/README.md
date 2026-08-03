# MediaFlow proxy (Zipx backend)

A tiny always-on service that turns a video **file-host** page (doodstream,
streamwish, mixdrop, voe, vidmoly, filelions, …) into a **direct playable
stream URL** — including the `Referer`/headers those hosts require — so the app
can play them in a native player and download them.

It runs on your Hostinger VPS. You deploy it; no credentials are shared with
anyone.

---

## 1. Deploy (first time)

SSH into the VPS, then:

```bash
# 0. If Docker isn't installed yet (Hostinger's "Ubuntu + Docker" template has it):
docker --version || curl -fsSL https://get.docker.com | sh

# 1. Put these files on the server
mkdir -p ~/mediaflow && cd ~/mediaflow
#    (copy docker-compose.yml and .env.example here — e.g. via scp or paste)

# 2. Create the secret
cp .env.example .env
sed -i "s/replace-with-a-long-random-string/$(openssl rand -hex 24)/" .env
cat .env          # note this password - the app will need it

# 3. Start it (pulls the image, runs in the background, restarts on reboot)
docker compose up -d

# 4. Confirm it's running
docker compose ps
docker compose logs --tail=20
```

## 2. Open the firewall port

The app needs to reach port **8888**. On the VPS:

```bash
sudo ufw allow 8888/tcp   # if ufw is active
```

Also check Hostinger's **hPanel → VPS → Firewall** and allow inbound TCP 8888.

## 3. Verify it's reachable

From your own machine/phone browser (replace with your VPS IP + password):

```
http://YOUR_VPS_IP:8888/extractor/video?host=doodstream&d=https://example.com/x&api_password=YOUR_PASSWORD
```

A JSON response (even an extraction error) = the server is up and
authenticating. `Connection refused` / timeout = firewall/port issue.
`401/403` = wrong `api_password`.

## 4. Endpoints the app will use

```
# Resolve a host page to a direct stream (+ required headers)
GET /extractor/video?host=<name>&d=<host_page_url>&api_password=<pw>

# Proxy an HLS manifest / segments (adds Referer etc.) - used for hosts
# that won't play unless the request comes from the proxy
GET /proxy/hls/manifest.m3u8?d=<m3u8_url>&h_Referer=<origin>&api_password=<pw>
```

Supported host names (case-insensitive): doodstream, streamwish, mixdrop, voe,
vidmoly, filelions, and ~18 more.

---

## Updating

```bash
cd ~/mediaflow
docker compose pull && docker compose up -d
```

## Next hardening (after it works)

- Put it behind a domain + HTTPS (e.g. Caddy reverse-proxy = automatic
  Let's Encrypt) so the app talks to it over TLS instead of plain HTTP.
- Keep `api_password` long and secret; it's the only thing gating the proxy.
