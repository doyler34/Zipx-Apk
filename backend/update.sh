#!/usr/bin/env bash
# Pulls the latest images for the Zipx backend services and restarts them, so
# the scrapers/resolvers stay current without touching the phone app.
#
# Run daily via cron (see backend/README.md). Safe to run any time - it only
# restarts a service if a newer image was pulled.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"

for service in tmdb-embed-api mediaflow; do
  dir="$here/$service"
  [ -f "$dir/docker-compose.yml" ] || continue
  echo "== $(date '+%Y-%m-%d %H:%M:%S') updating $service =="
  ( cd "$dir" && docker compose pull && docker compose up -d )
done

# Reclaim disk from the now-unused old images.
docker image prune -f
echo "== $(date '+%Y-%m-%d %H:%M:%S') done =="
