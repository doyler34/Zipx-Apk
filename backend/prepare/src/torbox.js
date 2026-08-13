// TorBox REST client (API v1). The key is read from TORBOX_API_KEY and is NEVER
// returned to any caller - all TorBox access happens here, server-side.
//
//   https://api.torbox.app/v1/api
//   POST /torrents/createtorrent   (magnet=...)          -> { data: { torrent_id, hash } }
//   GET  /torrents/mylist?id=<id>&bypass_cache=true      -> { data: { download_state,
//                                                              download_finished, progress,
//                                                              download_speed, files[] } }
//   GET  /torrents/requestdl?token=<key>&torrent_id=<id>&file_id=<fid> -> { data: "<url>" }
//   POST /torrents/controltorrent (torrent_id=..&operation=delete)
//
// Unlike Real-Debrid there is no per-file "select" step: TorBox downloads the
// whole torrent, and we request a direct link for the ONE file we want at play
// time. The app-side guard only ever submits single-file episode releases, so a
// TV submit is never a whole season pack.

const BASE = 'https://api.torbox.app/v1/api';

function token() {
  const t = process.env.TORBOX_API_KEY;
  if (!t) throw new Error('TORBOX_API_KEY not configured');
  return t;
}

async function tb(path, { method = 'GET', form, query } = {}) {
  const headers = { Authorization: `Bearer ${token()}` };
  let url = `${BASE}${path}`;
  if (query) url += (url.includes('?') ? '&' : '?') + new URLSearchParams(query).toString();
  let body;
  if (form) {
    body = new URLSearchParams(form).toString();
    headers['Content-Type'] = 'application/x-www-form-urlencoded';
  }
  const res = await fetch(url, { method, headers, body });
  const text = await res.text();
  let data = null;
  if (text) {
    try { data = JSON.parse(text); } catch { data = text; }
  }
  if (!res.ok) {
    const err = new Error(`TorBox ${method} ${path} -> ${res.status}`);
    err.status = res.status;
    err.data = data;
    throw err;
  }
  return data;
}

export const TorBox = {
  // Build the magnet server-side from a validated 40-hex infohash, so callers
  // can never push an arbitrary URL/magnet through us (no open proxy). Returns
  // TorBox's data object: { torrent_id, hash, ... } (or { queued_id } if queued).
  addMagnet: async (hash) => {
    const json = await tb('/torrents/createtorrent', {
      method: 'POST',
      form: { magnet: `magnet:?xt=urn:btih:${hash}`, seed: '3', allow_zip: 'false' },
    });
    if (!json || json.success === false) {
      const e = new Error('tb_add_failed');
      e.data = json;
      throw e;
    }
    return json.data || {};
  },

  // Single-torrent detail incl. files + live download state. bypass_cache so
  // polling reflects real progress (mylist is otherwise cached ~1 min).
  info: async (id) => {
    const json = await tb('/torrents/mylist', { query: { id: String(id), bypass_cache: 'true' } });
    let d = json && json.data != null ? json.data : null;
    if (Array.isArray(d)) d = d[0] || null;
    return d;
  },

  // Fresh, directly-playable URL for ONE file of a finished torrent. Generated
  // on demand each time (TorBox links are temporary) and never stored.
  requestDl: async (torrentId, fileId) => {
    const json = await tb('/torrents/requestdl', {
      query: { token: token(), torrent_id: String(torrentId), file_id: String(fileId) },
    });
    if (!json || json.success === false || !json.data) {
      const e = new Error('tb_requestdl_failed');
      e.data = json;
      throw e;
    }
    return json.data; // the URL string
  },

  delete: (id) =>
    tb('/torrents/controltorrent', { method: 'POST', form: { torrent_id: String(id), operation: 'delete' } }),
};
