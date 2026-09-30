# App icon

![Atrium's icon](images/app-icon.png)

**A skylight onto the cosmos**, Dave's pick (2026-09-29): the view straight up from inside a quiet hall, through a square skylight, at a glowing nebula. `images/app-icon.png` (1024 px, transparent outside the body) is the master; `Sources/Atrium/Resources/AppIcon.icns` is built from it (below) and named by `CFBundleIconFile` in `build.sh`. It shows in Finder, the Dock while Settings is open, Login Items, and Settings → About.

This first version was rendered with a throwaway Python script over a crop of Nebula's Oxygen palette (the app's own render, so there are no rights to clear), on the macOS grid: the body is 824 px square, centred, with continuous corners of about 185 px, and its outline matches the system icons' mask. A teal and gold sky (Nebula's Hubble palette) was the runner-up.

To rebuild the .icns from a new master:

```sh
mkdir AppIcon.iconset
for s in 16 32 128 256 512; do
  sips -z $s $s app-icon.png --out AppIcon.iconset/icon_${s}x${s}.png
  sips -z $((s*2)) $((s*2)) app-icon.png --out AppIcon.iconset/icon_${s}x${s}@2x.png
done
iconutil -c icns AppIcon.iconset -o Sources/Atrium/Resources/AppIcon.icns
```

Next: a layered Icon Composer `.icon` would get macOS 26's Liquid Glass treatment and its dark, tinted and clear looks, which a flat .icns can't. It needs Xcode's asset compiler (`actool`), since build.sh has no asset catalogue yet.

## Design prompt

For image models (Midjourney, DALL·E, Gemini…) or a designer working in Icon Composer.

**Concept.** Atrium is a calm menu bar app that plays slow, mostly photoreal wallpapers (nebulae, aurora, galaxies, a live night sky). The icon is the view straight up from inside a quiet hall: a square skylight well cut into a dark ceiling, and through its glass a glowing nebula in jewel tones with a few stars.

**Composition** (1024×1024 canvas, macOS 26 grid). One rounded-rectangle body, 824×824, centred (100 px margin), with continuous "squircle" corners of radius about 185. Outside the body it's transparent, apart from a soft drop shadow (about 10 px down, 14 px blur, 30% black). Inside:
- A flat ceiling with a square opening in it, about 630 px wide.
- Four trapezoid walls in one-point perspective, converging to a smaller glass pane about 465 px wide. The pane sits slightly above centre, so the bottom wall shows most. Crisp diagonal creases run where the walls meet.
- A thin cross of glass glazing bars.
- The sky fills the pane: dark space in one corner and a glowing cloud across the rest. This is the brightest area of the icon.

**Palette.**

| Element | Colour |
|---|---|
| Ceiling, top to bottom | deep indigo #30357A to #1B1D4A |
| Well shadow | #0F1134 |
| Lit near wall | #3A4488 |
| Deep space (never pure black) | #0D1236 |
| Nebula | teal #2FD3B0, rising to aquamarine #9AF3DF at the core |
| Accent | sapphire #3A7FC4 |
| Glass highlights | #E4ECFF |
| Optional warm accent | muted gold #C99A3F |

**Materials and lighting.**
- The ceiling and walls are matte, lit only by the sky. The walls brighten and pick up teal near the pane; the far (top) wall is darkest and the near (bottom) wall brightest.
- Liquid Glass: the pane's bezel and glazing bars are clear, lightly frosted glass that brightens what's behind it, with thin specular rims, brightest on the top-left and bottom-right edges.
- A hairline of light runs along the ceiling opening, and a thin rim of light along the top edge of the body.
- The sky is photoreal, in soft focus, with fine stars and at most one or two faint diffraction spikes.
- The feel is calm, quiet and premium: the flat lighting of Apple's macOS 26 icons, not glossy skeuomorphism.

**Icon Composer layers**, back to front:
1. Background: the body's ceiling gradient.
2. Well: the four walls, in flat tones with teal light near the pane.
3. Sky: the nebula image, clipped to the pane.
4. Glass: the bezel and glazing bars, in the translucent Liquid Glass material.
5. Highlights: the opening's hairline, the body's rim, and a faint sheen on the pane.

Keep the sky on its own layer, so the glass and the dark, tinted and clear looks act on it. Give the light look a lighter ceiling.

**Small sizes.** At 16 and 32 px it must read as a bright teal square inside a dark rounded square. Nothing smaller than 1/32 of the canvas should carry meaning; the bars and stars may vanish.

**Avoid:**
- Text or letters, and logos or brand marks.
- Four equal coloured squares, which look like the Windows logo.
- Pure black; neon or saturated magenta and lime.
- Heavy gloss or bevels, and lens flares.
- Busy starfields, people and furniture.
- A round porthole that looks like a camera lens.

**Variations:**
- **A. Aurora:** the same well, with the pane showing a green and violet aurora curtain over a thin dark mountain line along its lower edge.
- **B. Oculus:** a round, Pantheon-style skylight in the same ceiling, with one glass ring and no bars, and a nebula in teal and gold.
- **C. Teal and gold:** a Hubble-palette nebula (teal #2A9DB0 meeting gold #C99A3F), one glazing bar instead of a cross, and a lighter slate ceiling (#3B4270).

**Prompt suffixes.** For Midjourney, add `--ar 1:1 --style raw --no text, logo`. For any model, add "app icon, centred, plain white background".
