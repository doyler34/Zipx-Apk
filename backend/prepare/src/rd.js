// Real-Debrid REST client (API v1.0). The token is read from the RD_API_KEY
// environment variable and is NEVER returned to any caller - all Real-Debrid
// access happens here, server-side.
//
// Endpoints/status names below are the actual Real-Debrid API ones:
//   https://api.real-debrid.com/rest/1.0
//   POST   /torrents/addMagnet        -> { id, uri }
//   POST   /torrents/selectFiles/{id} -> 204 (files = comma ids, or "all")
//   GET    /torrents/info/{id}        -> { status, progress, speed, files[], ... }
//   DELETE /torrents/delete/{id}      -> 204

const BASE = 'https://api.real-debrid.com/rest/1.0';

function token() {
  const t = process.env.RD_API_KEY;
  if (!t) throw new Error('RD_API_KEY not configured');
  return t;
}

async function rd(path, { method = 'GET', form } = {}) {
  const headers = { Authorization: `Bearer ${token()}` };
  let body;
  if (form) {
    body = new URLSearchParams(form).toString();
    headers['Content-Type'] = 'application/x-www-form-urlencoded';
  }
  const res = await fetch(`${BASE}${path}`, { method, headers, body });
  const text = await res.text();
  let data = null;
  if (text) {
    try { data = JSON.parse(text); } catch { data = text; }
  }
  if (!res.ok) {
    const err = new Error(`RD ${method} ${path} -> ${res.status}`);
    err.status = res.status;
    err.data = data;
    throw err;
  }
  return data;
}

export const RealDebrid = {
  // Build the magnet server-side from a validated 40-hex infohash, so callers
  // can never push an arbitrary URL/magnet through us (no open proxy).
  addMagnet: (hash) =>
    rd('/torrents/addMagnet', { method: 'POST', form: { magnet: `magnet:?xt=urn:btih:${hash}` } }),
  selectFiles: (id, fileIds) =>
    rd(`/torrents/selectFiles/${id}`, { method: 'POST', form: { files: fileIds.join(',') } }),
  info: (id) => rd(`/torrents/info/${id}`),
  delete: (id) => rd(`/torrents/delete/${id}`, { method: 'DELETE' }),
  // Turn a cached RD file link into a fresh, directly-playable URL. Generated on
  // demand each time (RD's `download` links are temporary) and never stored.
  unrestrict: (link) => rd('/unrestrict/link', { method: 'POST', form: { link } }),
};
