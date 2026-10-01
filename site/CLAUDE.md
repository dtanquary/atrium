# atrium.show

Atrium's website. Its job is to show the art: the wallpapers are the product and the site is their gallery. The words, the download button and the credits all step aside for them. It's a static site on Cloudflare Pages, served from `site/public/`. The app is described in `../CLAUDE.md`, and each wallpaper in `../docs/`.

`../../CLAUDE.md` belongs to dtanquary.com. Its design system (Dark Liquid Glass, Inter, #6eb1ff) doesn't apply here; only its Cloudflare account rule does. That file sits outside this repo, which is public, and it's the only place the account ID is written down. Never put the account ID, an API token, or a `wrangler.toml` with `account_id` in this repo.

**The design is `design.md`**, the Claude Design handoff: hard rules, the verbatim copy, colour and type tokens, and nine directions. Its layout values came from frames drawn in HTML; the lab pages carry them now. Where this file and `design.md` differ, `design.md` wins on look and copy, and this file on how the site is built.

## Principles, in order
1. **The art is the page.** Atrium's own wallpapers fill the screen, moving (at least 80% of the viewport). The site draws no decoration of its own: no gradient blobs, glows, glass, noise, 3D, stock photos or AI-generated images. The only pictures are Atrium's own renders, its Settings window and its icon. The page is near black (`#0A0A0B`), and its one accent comes from the work on screen.
2. **Calm, like the app.** Dave's direction in `../docs/README.md` applies here too: slow, ambient, soft and dim. Crossfades of a second or more, never a hard cut, even on first paint. No bounce, spring, parallax or scroll-jacking; the page scrolls like a page.
3. **Modern by being native.** `@property`, `color-mix()` in OKLCH, `animation-timeline: view()`, `clip-path`, variable fonts, AV1. Where a feature is missing, the page falls back to a still one that is just as beautiful.
4. **Honest.** Only the copy in `design.md`. No invented testimonials, download counts, press quotes or features.

## What's built
- `public/lab/shared.js` and `shared.css`: the stage (one looping video per work, stacked full screen), `rooms()` (crossing into a section crossfades its work and words over time) and `canvas()` (scroll position scrubs the dissolve), the accent, pause with the tab, and arrow keys between rooms. A page lists its sections as one-screen-tall elements with `data-work` and lays out its own words.
- `public/lab/a/`, `b/`, `c/`: directions 2a The Exhibition (rooms, with revisions R1–R3), 2b One Endless Canvas (canvas) and 2c The Skylight (rooms, with a `clip-path` skylight that the first screen of scrolling widens). Each is one HTML file with its own CSS.
- `public/index.html`: a chooser while the directions are compared. The chosen direction replaces it.
- `public/credits.html`: the photographs and data inside the six works. The Fish Tank list was generated from `../Sources/Atrium/Resources/reef-credits.tsv` (one line per source); regenerate it if the reef changes. CC BY requires credit on the site itself, so every direction's download section links to it.
- `public/fonts/`: Instrument Sans, Figtree and Newsreader, variable, Latin only, from Google Fonts (OFL). Self-hosted: no third-party requests.

## Media
Every image comes from the app's own renderer, never a screen recording, so the site shows exactly what the app draws.
- `site/media.sh [slug…]` renders each work with the snapshot test at 30 fps (`SNAPSHOT_MOVIE_FPS=30`) and its look's settings (e.g. `nebula.palette=Hubble`, `galaxy.kind=Whirlpool`), crossfades the last 2 s of a 14 s render into its first 2 s so the 12 s loop has no seam, and writes AV1 and HEVC (Safari on M1 and M2 can't decode AV1) plus a JPEG poster of the first frame to `public/media/`. That folder is gitignored, so the script is the source of truth. About 1.5 minutes a work.
- Desktop is 2560 wide; phones get a 3:4 portrait slab cut around the work's focal point from `design.md`, at 1080×1440. `shared.js` picks phone media on portrait screens. The `codecs` strings in `shared.js` match the levels the encodes come out at; check with `ffprobe` if the sizes change.
- Nebula rolls a new nebula every render. Re-render until the roll suits the skylight's square and the phone crop.
- ffmpeg and swift test read stdin; in the script's loop they must not (`-nostdin`, `</dev/null`), or they swallow the list of works.

## Access and performance
- Only works on screen play; the rest wait with `preload="none"` until they're next. Everything pauses with the tab.
- `prefers-reduced-motion` gets the posters and no skylight widening, and the crossfades stay (dissolves are what Reduce Motion asks for).
- Still to do once a direction is chosen: a visible control that pauses all motion (WCAG 2.2.2), placed where that direction has room for it.
- No analytics, cookies, trackers or third-party requests.

## Build and deploy
- Plain HTML, CSS and JS in `public/`: no framework, no build step, no npm packages. `npx wrangler` is the only tool. Run it from `site/` so its `.wrangler/` state lands there (gitignored).
- Pages serves static files whole (a 200, even for a range request), and Safari won't play video from a server like that. `functions/media/[[path]].js` answers byte ranges for `/media/*`; `node site/range-check.mjs` checks it. If traffic outgrows the free tier of Function calls, cache `/media` with a Cache Rule on atrium.show, or move it to R2.
- Preview: `cd site && npx wrangler pages dev public --port 8788 --compatibility-date=2026-04-01` (the installed wrangler's runtime is older than today's date). Run from `site/` it serves the Function too.
- Check every change at 1440×900 and 390×844, at several scroll positions and with reduced motion, with no console errors, and look at the screenshots. Headless Chrome over the DevTools protocol works when the Chrome extension isn't connected (launch it with `--remote-allow-origins=*`).
- Deploy only to the Cloudflare account named in `../../CLAUDE.md`, never another: wrangler is logged in to two. Pass the ID on the command line, `CLOUDFLARE_ACCOUNT_ID=… npx wrangler pages deploy public --project-name atrium --branch lab`, so it never lands in a file here. `--branch lab` is the preview Dave opens on his phone (lab.atrium-4pv.pages.dev); production is `main`. `atrium.show` is registered in that account (2026-10-01) and gets attached to the project at launch.
- Other Claude sessions share this working tree (see `.git/atrium-claims.md`). Commit only site files, by explicit path. The site has no version number, and never bumps the app's.

## Plan
1. **Pick a direction** (now): 2a, 2b and 2c are built live with the real loops, on a preview branch. Dave compares them on his Mac and phone, and picks one or a mix.
2. **Build it:** the chosen direction at the root, with the pause control and a phone pass; delete `lab/` and the chooser.
3. **Polish:** a social card, a favicon from the icon, the title "Atrium: living wallpapers for Mac" and its meta description, page weights.
4. **Launch:** a production deploy, with atrium.show attached.

## Dave's direction so far
- 2026-09-30: art first, above everything: "ultra modern, but just as much if not more so artistic". Domain atrium.show, video loops rendered by the app, three directions to compare, and the site kept in `site/` in this repo.
- 2026-10-01: Dave registered atrium.show, in the same Cloudflare account. He doesn't want his Cloudflare details in this public repo.
- 2026-10-01: Claude Design explored nine directions (`design.md`); only the six works with wall labels appear. Dave picked 2c The Skylight, 2a The Exhibition and 2b One Endless Canvas to build live and compare.
