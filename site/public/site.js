// The canvas behind atrium.show: one looping video per work, stacked full screen and fixed. Scrolling a screen
// dissolves one section's work into the next, and the page's accent follows. The page lists its sections as
// one-screen-tall elements with data-work and lays out its own words.

/** Each work's accent: its render's dominant hue at oklch L 0.82, C ≤ 0.11, measured in the design handoff. */
const accents = {
  nebula: '#95d0d9', 'flowing-gradient': '#cab9f3', 'live-sky': '#b9c2ec',
  galaxy: '#ddbe9a', murmuration: '#ecb799', 'fish-tank': '#9bc5ff',
};
const media = new URL('media/', import.meta.url);
const kind = matchMedia('(max-aspect-ratio: 1/1)').matches ? 'phone' : 'desktop';
// AV1 first; Safari on M1 and M2 Macs can't decode it, and takes the HEVC copy. Levels match what media.sh makes.
const codecs = kind === 'desktop' ? { av1: 'av01.0.12M.08', hevc: 'hvc1.1.6.L150.90' } : { av1: 'av01.0.08M.08', hevc: 'hvc1.1.6.L120.90' };
const sections = [...document.querySelectorAll('[data-work]')];
const stage = document.querySelector('.stage');
const pause = document.querySelector('.pause');
const more = document.querySelector('.more'); // the glass pane with a card for every wallpaper
const root = document.documentElement;
let playing = !matchMedia('(prefers-reduced-motion: reduce)').matches; // Reduce Motion starts on the posters

for (const el of sections) if (!el.style.getPropertyValue('--own')) el.style.setProperty('--own', accents[el.dataset.work]); // each label's medium word, unless lifted

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
  stage.append(v);
}
const all = Object.values(videos);
const run = v => (playing && !document.hidden ? v.play().catch(() => {}) : v.pause());
const sync = () => all.forEach(v => (+v.style.opacity > 0 ? run(v) : v.pause()));
document.addEventListener('visibilitychange', sync); // pause with the tab, as the app pauses when covered

// A visible way to stop all motion (WCAG 2.2.2).
const label = () => { pause.textContent = playing ? 'Pause' : 'Play'; root.classList.toggle('is-paused', !playing); }; // laptop.js reads is-paused
pause.addEventListener('click', () => { playing = !playing; label(); sync(); });
label();

// The glass pane: the browser's own modal, so focus, Esc and holding the page still come with it. Its count comes
// from its cards, so it can't drift from them.
const count = `${more.querySelectorAll('.cards li').length} in the app`;
document.querySelector('.show-more').textContent = more.querySelector('h2').textContent = count;
document.querySelector('.show-more').addEventListener('click', () => more.showModal());
more.querySelector('.close').addEventListener('click', () => more.close());
more.addEventListener('click', e => { if (e.target === more) more.close(); }); // a click outside the pane

/** Start loading a work: its poster (the loop's first frame) and its video. */
function warm(slug) {
  const v = videos[slug];
  if (!v || v.preload === 'auto') return;
  v.poster = new URL(`${slug}-${kind}.jpg`, media);
  v.preload = 'auto';
  v.load();
}

/** `b` at opacity t over `a`, and the accent t of the way from a's to b's. */
function mix(a, b, t) {
  warm(a); // before play(): warming calls load(), which would cancel it
  warm(b);
  for (const [slug, v] of Object.entries(videos)) {
    const o = slug === a ? 1 : slug === b ? t : 0;
    v.style.opacity = o;
    v.style.zIndex = slug === b ? 2 : 1;
    o > 0 ? run(v) : v.pause();
  }
  root.style.setProperty('--accent', t > 0 ? `color-mix(in oklch, ${accents[a]}, ${accents[b]} ${(t * 100).toFixed(1)}%)` : accents[a]);
}

const clamp = i => Math.min(sections.length - 1, Math.max(0, i));
let queued = false;
function frame() {
  queued = false;
  const f = scrollY / sections[0].offsetHeight; // screens scrolled: 1.5 is halfway from the second work to the third
  const i = clamp(Math.floor(f)), t = Math.min(1, f - i);
  const a = sections[i].dataset.work, b = sections[clamp(i + 1)].dataset.work;
  mix(a, b, a === b ? 0 : t * t * (3 - 2 * t)); // smoothstep, so each work settles at either end
  warm(sections[i + 2]?.dataset.work);
  const last = f > sections.length - 1.5;
  document.body.classList.toggle('is-last', last);
  if (last) more.querySelectorAll('img[loading=lazy]').forEach(img => (img.loading = 'eager')); // ready before it opens
}
const queue = () => { if (!queued) { queued = true; requestAnimationFrame(frame); } };

// Fade the stage up from the ground once the first work's poster can draw, so even the first paint is a crossfade.
warm(sections[0].dataset.work);
const first = new Image();
first.src = videos[sections[0].dataset.work].poster;
first.decode().catch(() => {}).then(() => {
  stage.classList.add('is-ready');
  addEventListener('scroll', queue, { passive: true });
  addEventListener('resize', queue);
  frame();
});

// The pretend desktop's clock and calendar, in the visitor's own time and language, as the menu bar would show them.
const clock = document.querySelector('.clock'), day = document.querySelector('.cal-day'), date = document.querySelector('.cal-num');
const tick = () => {
  const now = new Date();
  clock.textContent = now.toLocaleString(undefined, { weekday: 'short', month: 'short', day: 'numeric', hour: 'numeric', minute: '2-digit' }).replace(/,/g, '');
  day.textContent = now.toLocaleString(undefined, { weekday: 'short' }).toUpperCase();
  date.textContent = now.getDate();
};
tick();
setInterval(tick, 20000);
