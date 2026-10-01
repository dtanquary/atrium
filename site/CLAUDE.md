# atrium.show

Atrium's website. Its job is to show the art: the wallpapers are the product and the site is their gallery. The words, the download button and the credits all step aside for them. It's a static site on Cloudflare Pages, served from `site/public/`. The app is described in `../CLAUDE.md`, and each wallpaper in `../docs/`.

`../../CLAUDE.md` belongs to dtanquary.com. Its design system (Dark Liquid Glass, Inter, #6eb1ff) doesn't apply here; only its Cloudflare account rule does. That file sits outside this repo, which is public, and it's the only place the account ID is written down. Never put the account ID, an API token, or a `wrangler.toml` with `account_id` in this repo.

## Principles, in order
1. **The art is the page.** Atrium's own wallpapers fill the screen, moving. When in doubt, make the art bigger and use fewer words. The site draws no decoration of its own: no gradient blobs, glows, noise, 3D, stock photos or AI-generated images. The only pictures are Atrium's own renders, its Settings window and its icon. The page's colours come from the work on screen: sample an accent per work into a custom property, and keep the rest near black.
2. **Calm, like the app.** Dave's direction in `../docs/README.md` applies here too: slow, ambient, soft and dim. Crossfades of a second or more, never a hard cut between works. No bounce, spring, parallax or scroll-jacking; the page scrolls like a page. Nothing flashy.
3. **Modern by being native.** Use what browsers now do well instead of libraries: scroll-driven animations (`animation-timeline: view()`), view transitions, `@property`, container queries, OKLCH and `color-mix()`, `text-wrap: balance`, a variable font, AV1 video and AVIF stills. Where a feature is missing, the page falls back to a still one that is just as beautiful.
4. **Honest.** Every claim traces to `../README.md` or `../docs/`. No invented testimonials, download counts, press quotes or features. Wallpapers go by the names the app gives them.

## What's on the page
One page, `index.html`, plus `credits.html`, in this order:
- **Opening:** a wallpaper playing full screen. The name, one line (the README's "living, animated desktop wallpapers" says it) and Download, small and off to one side.
- **The works:** every wallpaper in `../docs/README.md`'s table except those flagged `unfinished: true` in `../Sources/Atrium/Scenes.swift`. Each fills the screen with a wall label, as in a museum: its name and one line on what it's made of or from (e.g. "Shader · colours sampled from Hubble nebulae", "Live · the sky above you, right now"). Take that line from the wallpaper's doc. Order them for flow, not alphabetically, and open with Dave's favourites (Nebula, then Flowing Gradient).
- **Real, not made up:** the live wallpapers: the sky above you, your weather and wind, today's Sun, the ISS. A few words.
- **It's your desktop:** one view of a wallpaper behind desktop icons and a window, so it's clear what the product is, plus a Settings screenshot (`../docs/images/settings-*.jpg`) showing its live preview.
- **Easy on the Mac:** it pauses when covered, freezes in Low Power Mode, and costs about 2 ms a frame.
- **Download:** free; macOS 26 or later, on Apple silicon; the Gatekeeper steps from README → Download; the source on GitHub under MIT. Link to `https://github.com/dtanquary/atrium/releases/latest` once a release exists (`gh release list`), and to the repo until then.
- **Credits (`credits.html`):** every photo, map and data source the site shows, with author, license and source links. CC BY and CC BY-SA require credit on the site itself, not only in the app. Take them from README → Credits and `../Sources/Atrium/Resources/*-credits.tsv` and `*-photos.tsv`.

## Media
Every image comes from the app's own renderer, never a screen recording, so the site shows exactly what the app draws.
- `site/media.sh` renders each wallpaper with the snapshot test (`SNAPSHOT_SCENE`, `SNAPSHOT_MOVIE`, `SNAPSHOT_DEFAULTS`; see `../CLAUDE.md`) and writes a loop and a poster per work to `public/media/`. Use the settings behind each look in `../docs/images` (e.g. `nebula-hubble`, `galaxy-whirlpool`). `../docs/README.md` → Screenshots says how to seed the caches for live data. `public/media/` is gitignored, so the script is the source of truth.
- Loops must be seamless: render a few seconds extra and crossfade the tail into the head (ffmpeg `xfade`). 8–12 s each.
- The test saves 15 fps (`frame % 2 == 0` in `../Tests/AtriumTests/RenderTests.swift`). If motion looks stepped, add a `SNAPSHOT_MOVIE_FPS` option there rather than interpolating.
- Encode AV1 first with an H.264 fallback, in `<source>` order, plus a rendition about 1080 px wide for phones. The poster is the loop's first frame. Keep each loop to a few MB; Pages caps a file at 25 MiB.
- Phones are portrait, but the wallpapers are 16:10. Try rendering portrait loops (add a `SNAPSHOT_SIZE` option to the test). Keep the ones that look right, and crop the rest with a per-work `object-position`.

## Performance and access
- Only videos on screen play (IntersectionObserver). The rest use `preload="none"` with posters. The opening poster shows at once.
- `prefers-reduced-motion` and Save-Data get stills, and a visible control pauses all motion (WCAG 2.2.2).
- Text over art meets WCAG AA contrast, with a soft scrim where needed. Every work has alt text, and keyboard use and focus styles work throughout. It works from 390 px phones to 5K displays.
- No analytics, cookies, trackers or third-party requests. Fonts are self-hosted.

## Build and deploy
- Plain HTML, CSS and JS in `public/`: no framework, no build step, no npm packages. `npx wrangler` is the only tool.
- Preview with `npx wrangler pages dev site/public`. Check it in a browser at 1440×900 and 390×844, and with reduced motion on. Keep the console clean, and look at screenshots before calling anything done.
- Deploy only to the Cloudflare account named in `../../CLAUDE.md`, never another. Pass its ID on the command line as `CLOUDFLARE_ACCOUNT_ID=… npx wrangler pages deploy site/public --project-name atrium`, so it never lands in a file here. Add `--branch <name>` for a preview URL Dave can open on his phone. `atrium.show` is registered in that account (2026-10-01) and gets attached as the project's custom domain at launch.
- Other Claude sessions share this working tree (see `.git/atrium-claims.md`). Commit only site files, by explicit path. The site has no version number, and never bumps the app's.

## Plan
1. **Pick a direction** (compare, then lock in, as with the app's big looks). Write `media.sh` and render the handful of works the lab needs. Then build the opening and the first three or four works three ways, at `public/lab/a/`, `b/` and `c/`, sharing one media folder, and deploy them to a preview branch. The words are the same in all three, so only the design differs. Each direction also tries its own typeface.
   - **A. The Exhibition:** a gallery walk. Each work fills the screen with a small wall label; scrolling moves from room to room through slow crossfades.
   - **B. One Endless Canvas:** one wallpaper fills the viewport all the way down and slowly turns into the next as you scroll; the words float over it and pass by.
   - **C. The Skylight,** after the icon ("a skylight onto the cosmos", `../docs/app-icon.md`): the page opens in darkness on an opening that widens into full-screen art as you scroll, then walks through the works.
2. **Build it:** the whole page and credits in the direction Dave picks (or his mix of them). Delete the other directions.
3. **Polish:** a social card, a favicon from the icon, the title "Atrium: living wallpapers for Mac" and a meta description, a phone pass, and page weights.
4. **Launch:** a production deploy, with atrium.show attached.

## Dave's direction so far
- 2026-09-30: art first, above everything: "ultra modern, but just as much if not more so artistic". Domain atrium.show, video loops rendered by the app, three directions to compare, and the site kept in `site/` in this repo.
- 2026-10-01: Dave registered atrium.show, in the same Cloudflare account. He doesn't want his Cloudflare details in this public repo.
