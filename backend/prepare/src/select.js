// Chooses which file of a TorBox torrent to hand back for playback, so a TV
// season pack only plays the requested episode and a movie plays the main video
// file - never a sample/extra by accident.
//
// TorBox downloads the whole torrent, so (unlike Real-Debrid) this runs at PLAY
// time and returns a single file id to request a download link for.

const VIDEO_RE = /\.(mkv|mp4|avi|m4v|mov|ts|webm)$/i;
const SAMPLE_RE = /(^|[^a-z0-9])sample([^a-z0-9]|$)/i;
const EXTRAS_RE =
  /(^|[^a-z0-9])(extras?|featurettes?|trailers?|bonus|behind[.\s_-]?the[.\s_-]?scenes)([^a-z0-9]|$)/i;

// TorBox files carry `name` (full path) + `size`; tolerate `path`/`bytes` too.
const pathOf = (f) => String(f.name || f.path || '');
const sizeOf = (f) => Number(f.size ?? f.bytes ?? 0);
const basename = (p) => String(p || '').split('/').pop();
const isVideo = (f) => VIDEO_RE.test(pathOf(f));
const isJunk = (f) => SAMPLE_RE.test(basename(pathOf(f))) || EXTRAS_RE.test(basename(pathOf(f)));

// S/E matchers for a season+episode: S02E07 / s2e7, 2x07, and a bare E07.
function episodeMatchers(season, episode) {
  const s = Number(season);
  const e = Number(episode);
  return [
    new RegExp(`s0*${s}[ ._-]*e0*${e}(?![0-9])`, 'i'),
    new RegExp(`(^|[^0-9])0*${s}[ ._-]*x[ ._-]*0*${e}(?![0-9])`, 'i'),
    new RegExp(`(^|[^0-9])e0*${e}(?![0-9])`, 'i'),
  ];
}

// Returns { fileId, reason } on success, or { error } on failure. On a TV pack
// where the episode can't be uniquely identified, it fails safely rather than
// guessing.
//
// `fileIdx` is AIOStreams' structured file index (0-based, within the torrent).
// It's the PREFERRED selector when valid; everything else is the fallback.
export function selectFile(files, { mediaType, season, episode, fileIdx }) {
  const all = files || [];

  // Preferred: AIOStreams' structured index. TorBox file ids are 0-based in
  // torrent order, so try id === fileIdx first, then the positional file, and
  // only trust it if it lands on a real, non-sample/extras video file. A wrong
  // or out-of-range index simply falls through to the matching logic below.
  if (Number.isInteger(fileIdx) && fileIdx >= 0) {
    const byId = all.find((f) => f.id === fileIdx);
    const byPos = all[fileIdx];
    const target = byId && isVideo(byId) && !isJunk(byId) ? byId
      : byPos && isVideo(byPos) && !isJunk(byPos) ? byPos
      : null;
    if (target) return { fileId: target.id, reason: 'aiostreams_index' };
  }

  const videos = all.filter(isVideo);
  if (videos.length === 0) return { error: 'no_video_file' };

  const clean = videos.filter((f) => !isJunk(f));
  const pool = clean.length ? clean : videos;

  if (mediaType === 'tv') {
    const matchers = episodeMatchers(season, episode);
    const matches = pool.filter((f) => matchers.some((re) => re.test(basename(pathOf(f)))));
    if (matches.length === 1) return { fileId: matches[0].id, reason: 'episode_matched' };
    if (matches.length > 1) {
      const largest = matches.slice().sort((a, b) => sizeOf(b) - sizeOf(a))[0];
      return { fileId: largest.id, reason: 'episode_matched_largest' };
    }
    if (pool.length === 1) return { fileId: pool[0].id, reason: 'single_file' };
    return { error: 'episode_not_identified' };
  }

  // Movie: the largest clean video file (samples/extras already dropped).
  const largest = pool.slice().sort((a, b) => sizeOf(b) - sizeOf(a))[0];
  return { fileId: largest.id, reason: 'largest_video' };
}
