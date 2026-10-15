// The opening (Dave, 2026-10-01, after 2c's skylight): in the dark, a closed laptop opens its lid on the desktop,
// and the first screen of scrolling brings its screen up to fill the window; the last screen pulls back out to it.
// It builds the laptop around the page's own menu bar and Dock (and stage, on landscape screens), and laptop.css only
// applies once it has, so deleting the two lines that load these files from index.html turns it off cleanly.
//
// Portrait screens (most phones) get a landscape screen as tall as the window, so it overflows the sides. It plays
// its own small landscape loops, and as it zooms it slides to the part the portrait wallpaper shows: that crop's
// focal point (media.sh). Once it fills the window, that region at that scale is exactly the full-window
// wallpaper, which fades in over it, its loop set to the same moment. The end does the same in reverse.

{
  const still = matchMedia('(prefers-reduced-motion: reduce)').matches;
  const portrait = !matchMedia('(min-aspect-ratio: 1/1)').matches;
  const root = document.documentElement;
  const add = (cls, parent) => parent.appendChild(Object.assign(document.createElement('div'), { className: cls }));
  const device = document.createElement('div');
  device.className = 'device';
  device.setAttribute('aria-hidden', 'true');
  add('deck', device);
  const front = add('front', device);
  const lid = add('lid', device);
  add('lid-back', lid);
  add('bezel', lid);
  const screen = add('screen', lid);
  screen.append(...document.querySelectorAll(portrait ? '.menubar, .dock' : '.stage, .menubar, .dock'));
  add('notch', lid); // its own surface on the lid, not inside the screen, so Safari draws it while the lid swings
  document.body.prepend(device);
  root.classList.add('laptop');
  root.classList.toggle('portrait', portrait);
  if (still) root.classList.add('is-paused'); // as site.js will, which runs after this

  const sections = document.querySelectorAll('[data-work]');
  const first = sections[0], n = sections.length;
  const firstWork = first.dataset.work, lastWork = sections[n - 1].dataset.work;
  const set = (name, value) => root.style.setProperty(name, value);
  set('--last', n - 2); // the screen the zoom out starts on (laptop.css)

  // Portrait: the screen's own loops, and where each portrait crop is centred, as a share of the width. These mirror
  // media.sh's focal points, held clear of the edges the way its 3:4 slab is.
  const focal = { nebula: 0.54, meander: 0.5, etching: 0.76, 'pixel-window-seat': 0.7, murmuration: 0.44, 'fish-tank': 0.42 };
  const centre = slug => Math.min(0.757, Math.max(0.243, focal[slug] ?? 0.5));
  const loop = slug => {
    const v = document.createElement('video');
    for (const a of ['muted', 'loop', 'playsinline']) v.setAttribute(a, '');
    v.muted = true;
    v.className = 'loop';
    v.preload = 'none';
    for (const [c, codec] of [['av1', 'av01.0.04M.08'], ['hevc', 'hvc1.1.6.L93.90']]) {
      const s = document.createElement('source');
      s.src = `media/${slug}-laptop.${c}.mp4`;
      s.type = `video/mp4; codecs="${codec}"`;
      v.append(s);
    }
    v.warm = () => { if (v.preload !== 'auto') { v.poster = `media/${slug}-laptop.jpg`; v.preload = 'auto'; v.load(); } };
    screen.prepend(v);
    return v;
  };
  const opening = portrait && loop(firstWork), closing = portrait && lastWork !== firstWork ? loop(lastWork) : opening;
  if (portrait) opening.warm();
  const canvasLoop = slug => [...document.querySelectorAll('.stage video')].find(v => v.currentSrc.includes(`/${slug}-`));
  /** Carries a loop's moment over to its twin, so the hand-over between them can't be seen. */
  const carry = (from, to) => { if (from && to && from.readyState >= 2 && to.readyState >= 1 && Math.abs(from.currentTime - to.currentTime) > 0.15) to.currentTime = from.currentTime; };

  let W, H, room; // the window's width, the laptop's height (the large viewport) and the room it has (the small one)

  /** Sizes the laptop to fit the dark around it, measured with the deck in perspective, and sets the zoom's ends
   *  for laptop.css. Not on every resize: a phone's toolbars moving as it scrolls change none of these. */
  function fit() {
    if (W === innerWidth && H === device.offsetHeight && room === first.offsetHeight) return;
    W = innerWidth; H = device.offsetHeight; room = first.offsetHeight;
    const sw = portrait ? H * 2560 / 1662 : W; // the screen's width; portrait: the loops' own shape, as tall as the laptop
    set('--u', `${sw / 100}px`);
    set('--h', `${H}px`);
    device.style.animation = 'none'; // measured full size
    const below = front.getBoundingClientRect().bottom - H / 2; // centre of the screen to the laptop's front edge
    device.style.animation = '';
    const above = H / 2 + 0.016 * sw; // centre of the screen to the top of the bezel
    const wide = (W - 40) / (sw * 1.032 * 1.1); // the bezel, and the base's front a tenth wider in perspective
    // Centred in the dark between the site's bar and the words below, as big as fits.
    const place = (bottom, cap) => {
      const s = Math.min(cap, (room - 100 - bottom) / (above + below), wide);
      return [s, (100 + room - bottom) / 2 - s * (below - above) / 2 - H / 2];
    };
    const [s0, y0] = place(150, 0.62); // above the opening lines
    const [s1, y1] = place(portrait ? 190 : 200, s0); // above the download screen's words
    set('--s0', s0); set('--y0', `${y0}px`);
    set('--s1', s1); set('--y1', `${y1}px`);
    // Portrait: slide so the crop's centre meets the window's as the screen fills it.
    set('--x0', `${portrait ? (0.5 - centre(firstWork)) * sw : 0}px`);
    set('--x1', `${portrait ? (0.5 - centre(lastWork)) * sw : 0}px`);
  }

  let queued = false, handed = false, taken = false;
  /** Portrait: which loop the laptop's screen plays, lined up with the full-window one at each hand-over. */
  function frame() {
    queued = false;
    if (!portrait) return;
    const f = scrollY / room;
    const end = f > n - 2; // past the last label: the closing loop
    if (f > n - 3) closing.warm();
    // Line the twins up just before each hand-over, once per pass.
    if (f > 0.5 && f < 1 && !handed) { carry(opening, canvasLoop(firstWork)); handed = true; }
    if (f < 0.5) handed = false;
    if (end && !taken) { carry(canvasLoop(lastWork), closing); taken = true; }
    if (!end) taken = false;
    const run = (f < 1 || end) && !root.classList.contains('is-paused') && !document.hidden; // while the laptop shows
    for (const v of new Set([opening, closing])) {
      const on = v === (end ? closing : opening);
      v.style.opacity = on ? 1 : 0;
      on && run ? v.play().catch(() => {}) : v.pause();
    }
  }
  const queue = () => { if (!queued) { queued = true; requestAnimationFrame(frame); } };
  fit();
  frame();
  addEventListener('scroll', queue, { passive: true });
  addEventListener('resize', () => { fit(); queue(); });
  document.addEventListener('visibilitychange', queue);
  document.querySelector('.pause').addEventListener('click', queue); // site.js sets is-paused first
  document.addEventListener('DOMContentLoaded', queue); // once site.js has run and found the canvas's loops
  // Open the lid once the closed laptop has been drawn. Reduce Motion starts it open, and so does arriving partway
  // down the page, where the screen already fills the window.
  if (still || scrollY > first.offsetHeight / 2) {
    lid.style.transition = 'none'; // no swing
    root.classList.add('is-opening');
  } else requestAnimationFrame(() => requestAnimationFrame(() => root.classList.add('is-opening')));
}
