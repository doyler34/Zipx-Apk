# Install page + update manifest

`index.html` is the download landing page, served from the VPS alongside the
built APK/installer (`zipx-movies.apk`, `ZipX-Setup.exe`) that CI uploads
there via SCP (see `.github/workflows/build-apk.yml` / `build-windows.yml`).

## App Updates (Profile -> App Updates)

The app's optional in-app update check (never forced, never runs at
startup - see `lib/core/update/app_update_service.dart`) fetches a small JSON
manifest and compares its `version` against the installed one.

To announce a new release from your own VPS instead of the GitHub Releases
default (so the app never talks to github.com at all):

1. Copy `update-manifest.example.json` to `update-manifest.json` in this same
   directory (so it lives next to `index.html` and the binaries, served over
   plain HTTP(S) exactly like them).
2. After uploading a new build, edit it: bump `version` (must be numerically
   newer - dot-separated integers, e.g. `1.0.189` > `1.0.188`), update
   `android_url`/`windows_url` if they've moved, and write the
   `release_notes` shown in the app.
3. Add a `VPS_PUBLIC_URL` repo secret (Settings -> Secrets and variables ->
   Actions) set to the public base URL this directory is served from, e.g.
   `https://dl.your-domain.com` (no trailing slash) - the same host/path
   `index.html`, `zipx-movies.apk` and `ZipX-Setup.exe` already live at.

Once `VPS_PUBLIC_URL` is set, both `build-apk.yml` and `build-windows.yml`
automatically build the app with
`--dart-define=UPDATE_MANIFEST_URL=$VPS_PUBLIC_URL/update-manifest.json` -
no manual dart-define or workflow edit needed per release. Leave the secret
unset and the app falls back to the GitHub Release asset instead (see the
`_manifestUrl` constant in `app_update_service.dart`); nothing else in the
app needs to change to switch between the two.

Note this only moves where the *app* fetches its manifest from - CI still
also publishes the APK/installer to GitHub Releases as before (that upload
isn't optional). If you want the download links themselves off GitHub too,
that's already handled by the existing `VPS_HOST`/`VPS_DOWNLOAD_DIR` secrets
("Upload APK/installer to VPS" steps) - just make sure `android_url`/
`windows_url` in `update-manifest.json` point at your VPS, not GitHub.
