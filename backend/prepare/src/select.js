// Chooses which file(s) of a Real-Debrid torrent to download, so a TV season
// pack only grabs the requested episode and a movie only grabs the main video
// file - never the whole pack by accident.

const VIDEO_RE = /\.(mkv|mp4|avi|m4v|mov|ts|webm)$/i;
const SAMPLE_RE = /(^|[^a-z0-9])sample([^a-z0-9]|$)/i;
const EXTRAS_RE =
  /(^|[^a-z0-9])(extras?|featurettes?|trailers?|bonus|behind[.\s_-]?the[.\s_-]?scenes)([^a-z0-9]|$)/i;

const isVideo = (f) => VIDEO_RE.test(f.path || '');
const basename = (p) => String(p || '').split('/').pop();
const isJunk = (f) => SAMPLE_RE.test(basename(f.path)) || EXTRAS_RE.test(basename(f.path));

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

// Returns { fileIds: [...], reason } on success, or { error } on failure.
// On a TV pack where the episode can't be uniquely identified, it fails safely
// rather than selecting every file (which would download the whole season).
//
// `fileIdx` is AIOStreams' structured file index (0-based, within the torrent).
// It's the PREFERRED selector when valid; everything else is the fallback.
export function selectFiles(files, { mediaType, season, episode, fileIdx }) {
  const all = files || [];

  // Preferred: AIOStreams' structured index. Real-Debrid file ids are 1-based
  // in torrent order, so the torrent's 0-based index maps to id === fileIdx + 1.
  // Only trust it if it lands on a real, non-sample/extras video file - a wrong
  // or out-of-range index simply falls through to the matching logic below.
  if (Number.isInteger(fileIdx) && fileIdx >= 0) {
    const target = all.find((f) => f.id === fileIdx + 1);
    if (target && isVideo(target) && !isJunk(target)) {
      return { fileIds: [target.id], reason: 'aiostreams_index' };
    }
  }

  const videos = all.filter(isVideo);
  if (videos.length === 0) return { error: 'no_video_file' };

  const clean = videos.filter((f) => !isJunk(f));
  const pool = clean.length ? clean : videos;

  if (mediaType === 'tv') {
    const matchers = episodeMatchers(season, episode);
    const matches = pool.filter((f) => matchers.some((re) => re.test(basename(f.path))));
    if (matches.length === 1) return { fileIds: [matches[0].id], reason: 'episode_matched' };
    if (matches.length > 1) {
      // More than one file matched (rare) - take the largest match, still just
      // ONE file, never the whole pack.
      const largest = matches.slice().sort((a, b) => b.bytes - a.bytes)[0];
      return { fileIds: [largest.id], reason: 'episode_matched_largest' };
    }
    // No explicit S/E match: a single-video torrent must be the episode.
    if (pool.length === 1) return { fileIds: [pool[0].id], reason: 'single_file' };
    // Multiple files, none identifiable as the requested episode - fail safely.
    return { error: 'episode_not_identified' };
  }

  // Movie: the largest clean video file (samples/extras already dropped).
  const largest = pool.slice().sort((a, b) => b.bytes - a.bytes)[0];
  return { fileIds: [largest.id], reason: 'largest_video' };
}
