// The stage behind every direction on atrium.show: one looping video per work, stacked full screen, crossfading as
// the visitor scrolls, with the page's accent following whichever work is showing. A page lists its sections as
// elements with data-work, one screen tall each, and lays out its own words; rooms() or canvas() does the rest.

/** Each work's accent: its render's dominant hue at oklch L 0.82, C ≤ 0.11, measured in the design handoff. */
export const accents = {
  nebula: '#95d0d9', 'flowing-gradient': '#cab9f3', 'live-sky': '#b9c2ec',
  galaxy: '#ddbe9a', murmuration: '#ecb799', 'fish-tank': '#9bc5ff',
};
export const still = matchMedia('(prefers-reduced-motion: reduce)').matches;

const media = new URL('../media/', import.meta.url);
const kind = matchMedia('(max-aspect-ratio: 1/1)').matches ? 'phone' : 'desktop';
// AV1 first; Safari on M1 and M2 Macs can't decode it, and takes the HEVC copy. Levels match what media.sh makes.
const codecs = kind === 'desktop' ? { av1: 'av01.0.12M.08', hevc: 'hvc1.1.6.L150.90' } : { av1: 'av01.0.08M.08', hevc: 'hvc1.1.6.L120.90' };
const sections = [...document.querySelectorAll('[data-work]')];
const stageEl = document.querySelector('.stage');

/** One muted, looping video per work in `.stage`. show() crossfades by time, mix() by scroll position. */
function stage() {
  const root = document.documentElement;
  let current, z = 0, settle;
  const videos = {};
  for (const slug of new Set(sections.map(s => s.dataset.work))) {
    const v = videos[slug] = document.createElement('video');
    for (const a of ['muted', 'loop', 'playsinline']) v.setAttribute(a, '');
    v.muted = true;
    v.preload = 'none';
    v.className = 'art';
    for (const [c, codec] of Object.entries(codecs)) {
      const s = document.createElement('source');
      s.src = new URL(`${slug}-${kind}.${c}.mp4`, media);
      s.type = `video/mp4; codecs="${codec}"`;
      v.append(s);
    }
    stageEl.append(v);
  }
  const all = Object.values(videos);
  const run = v => (!still && !document.hidden ? v.play().catch(() => {}) : v.pause());
  const shown = v => v.classList.contains('is-on') || +v.style.opacity > 0;
  const sync = () => all.forEach(v => (shown(v) ? run(v) : v.pause()));
  document.addEventListener('visibilitychange', sync); // pause with the tab, as the app pauses when covered

  /** Start loading a work: its poster (the loop's first frame) and its video. */
  function warm(slug) {
    const v = videos[slug];
    if (!v || v.preload === 'auto') return;
    v.poster = new URL(`${slug}-${kind}.jpg`, media);
    v.preload = 'auto';
    v.load();
  }

  return {
    warm,
    /** Resolves once the work's poster can be drawn, so the first fade-up never fades up nothing. */
    ready(slug) {
      warm(slug);
      const img = new Image();
      img.src = videos[slug].poster;
      return img.decode().catch(() => {});
    },
    /** Rooms: the work fades up over the others; CSS sets the durations (--fade-in, --fade-out). */
    show(slug) {
      if (slug === current) return;
      current = slug;
      warm(slug);
      videos[slug].style.zIndex = ++z;
      all.forEach(v => v.classList.toggle('is-on', v === videos[slug]));
      root.style.setProperty('--accent', accents[slug]);
      run(videos[slug]);
      clearTimeout(settle);
      settle = setTimeout(sync, 2500); // pause what has faded out
    },
    /** Canvas: `b` at opacity t over `a`, and the accent t of the way from a's to b's. */
    mix(a, b, t) {
      warm(a); // before play(): warming calls load(), which would cancel it
      warm(b);
      for (const [slug, v] of Object.entries(videos)) {
        const o = slug === a ? 1 : slug === b ? t : 0;
        v.style.opacity = o;
        v.style.zIndex = slug === b ? 2 : 1;
        o > 0 ? run(v) : v.pause();
      }
      root.style.setProperty('--accent', t > 0 ? `color-mix(in oklch, ${accents[a]}, ${accents[b]} ${(t * 100).toFixed(1)}%)` : accents[a]);
    },
  };
}

/** Calls fn(f) on scroll and resize, where f counts screens scrolled (1.5 = halfway into the second section). */
export function onScroll(fn) {
  let queued = false;
  const tick = () => { queued = false; fn(scrollY / sections[0].offsetHeight); };
  const queue = () => { if (!queued) { queued = true; requestAnimationFrame(tick); } };
  addEventListener('scroll', queue, { passive: true });
  addEventListener('resize', queue);
  tick();
}

const clamp = i => Math.min(sections.length - 1, Math.max(0, i));

/** Rooms that hold still: crossing into one fades its work and its words up over the last. Returns the stage. */
export function rooms(onRoom = () => {}) {
  const s = stage();
  for (const el of sections) el.style.setProperty('--own', accents[el.dataset.work]);
  let last = -1;
  s.ready(sections[0].dataset.work).then(() => {
    stageEl.classList.add('is-ready');
    onScroll(f => {
      const i = clamp(Math.round(f));
      if (i === last) return;
      last = i;
      sections.forEach((el, j) => el.classList.toggle('is-current', j === i));
      document.body.classList.toggle('is-last', i === sections.length - 1);
      s.show(sections[i].dataset.work);
      s.warm(sections[i + 1]?.dataset.work);
      onRoom(i);
    });
  });
  // Arrow keys, Page Up/Down and space move a whole room.
  addEventListener('keydown', e => {
    const step = { ArrowDown: 1, PageDown: 1, ' ': e.shiftKey ? -1 : 1, ArrowUp: -1, PageUp: -1 }[e.key];
    if (!step || e.altKey || e.ctrlKey || e.metaKey || e.target.closest('button, input, textarea, select')) return;
    e.preventDefault();
    const h = sections[0].offsetHeight;
    scrollTo({ top: clamp(Math.round(scrollY / h) + step) * h, behavior: still ? 'instant' : 'smooth' });
  });
  return s;
}

/** One canvas that never moves: scrolling a screen dissolves one section's work into the next. */
export function canvas(onFrame = () => {}) {
  const s = stage();
  s.ready(sections[0].dataset.work).then(() => {
    stageEl.classList.add('is-ready');
    onScroll(f => {
      const i = clamp(Math.floor(f)), t = Math.min(1, f - i);
      const a = sections[i].dataset.work, b = sections[clamp(i + 1)].dataset.work;
      s.mix(a, b, a === b ? 0 : t * t * (3 - 2 * t)); // smoothstep, so each work settles at either end
      s.warm(sections[i + 2]?.dataset.work);
      document.body.classList.toggle('is-last', f > sections.length - 1.5);
      onFrame(f);
    });
  });
  return s;
}
