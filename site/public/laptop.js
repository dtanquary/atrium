// The opening (Dave, 2026-10-01, after 2c's skylight): in the dark, a closed laptop opens its lid on the desktop,
// and the first screen of scrolling brings its screen up to fill the window; the last screen pulls back out to it. It builds the laptop around the page's
// own stage, menu bar and Dock, and laptop.css only applies once it has, so deleting the two lines that load these
// files from index.html turns it off cleanly. Landscape screens wider than a phone only.

if (matchMedia('(min-width: 700px) and (min-aspect-ratio: 1/1)').matches) {
  const still = matchMedia('(prefers-reduced-motion: reduce)').matches;
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
  screen.append(...document.querySelectorAll('.stage, .menubar, .dock'));
  add('notch', lid); // its own surface on the lid, not inside the screen, so Safari draws it while the lid swings
  document.body.prepend(device);
  root.classList.add('laptop');

  const sections = document.querySelectorAll('[data-work]');
  const first = sections[0], n = sections.length;
  const set = (name, value) => root.style.setProperty(name, value);
  let s0, y0, s1, y1; // the laptop's scale and lift at the start, and on the last screen

  /** Sizes the laptop to fit the dark around it, measured with the deck in perspective. */
  function fit() {
    const H = innerHeight;
    set('--s', 1); set('--y', '0px');
    const below = front.getBoundingClientRect().bottom - H / 2; // centre of the screen to the laptop's front edge
    const above = H / 2 + 0.016 * innerWidth; // centre of the screen to the top of the bezel
    s0 = Math.min(0.62, (H - 120 - 150) / (above + below)); // between the site's bar and the opening lines
    y0 = H / 2 - 150 - s0 * below;
    s1 = Math.min(s0, (H - 100 - 200) / (above + below)); // above the download screen's words
    y1 = H / 2 - 200 - s1 * below;
  }

  const smooth = t => (t = Math.min(1, Math.max(0, t)), still ? +(t >= 0.5) : t * t * (3 - 2 * t)); // Reduce Motion: a swap, not a zoom
  let queued = false;
  function frame() {
    queued = false;
    const f = scrollY / first.offsetHeight;
    const e = smooth(f), z = smooth(f - (n - 2)); // in over the first screen, back out over the last
    set('--s', z > 0 ? 1 + (s1 - 1) * z : s0 + (1 - s0) * e);
    set('--y', `${z > 0 ? y1 * z : y0 * (1 - e)}px`);
    set('--e', e);
    set('--frame', Math.max(1 - e, z));
  }
  const queue = () => { if (!queued) { queued = true; requestAnimationFrame(frame); } };
  fit();
  frame();
  addEventListener('scroll', queue, { passive: true });
  addEventListener('resize', () => { fit(); frame(); });
  // Open the lid once the closed laptop has been drawn. Reduce Motion starts it open, and so does arriving partway
  // down the page, where the screen already fills the window.
  if (still || scrollY > first.offsetHeight / 2) {
    lid.style.transition = 'none';
    root.classList.add('is-opening');
  } else requestAnimationFrame(() => requestAnimationFrame(() => root.classList.add('is-opening')));
}
