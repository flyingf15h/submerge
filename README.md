# Submerge

A late night koi pond for KDE Plasma 5, styled like an old game loading screen.

This is the `plasma5` branch, a port of `main` (Plasma 6) to Plasma 5.27 / Qt 5.15. It looks and
behaves the same; see [Plasma 5 port](#plasma-5-port) for what changed underneath.

![Submerge](store/screenshots/submerge-1.jpg)

- **Live wallpaper**: koi that swim in bursts and glides and bend into their turns, real
  ripples from a small water simulation, caustic light along the top, and two or three big
  blurry glitching koi drifting past the glass.
- **HUD**: big clock, live CPU / GPU / memory / network / storage readouts (with the app using
  the most CPU and memory), and a system status line.
- **Tank monitor**: one specimen box that locks onto the fish nearest your cursor, a depth
  ruler, and tank conditions that are rerolled every boot. Warm water brings out the orange
  varieties, acidic water the teal ones, alkaline water the violet ones, low oxygen more juveniles.
- **Plasma style** for the panel and task manager, a **colour scheme**, and a **splash screen**.

## Install

Grab `submerge-1.0-plasma5.tar.gz` from [Releases](../../releases), then:

```sh
tar xzf submerge-1.0-plasma5.tar.gz
cd submerge-1.0-plasma5
./install.sh --apply
```

Without `--apply` it only installs; pick **Submerge** under System Settings > Colours & Themes >
Global Theme. `./uninstall.sh` removes it. Needs Plasma 5.27.

## From source

```sh
./install.sh        # copies the shaders into the package and installs the wallpaper
./preview.py        # live preview window (PyQt5, or qmlscene if PyQt5 has no QML) that restarts whenever a file changes
./build-dist.sh     # builds dist/submerge-<version>.tar.gz and the KDE Store archives
```

`prep.py` regenerates the tinted fish and water images from the original art, and
`plasma-style/build.py` builds the panel style.

## Plasma 5 port

- **Shaders:** `shaders/` holds GLSL 1.20 versions of main's GLSL 4.40 sources (same code and
  comments; the uniform block is split into plain uniforms, which Qt 5 binds by name). Qt 5
  compiles them at runtime, so there is no qsb step. Rendered with the same inputs, every shader
  matches main's compiled `.qsb` pixel for pixel.
- **Ripples:** Qt 5 has no `RGBA16F` enum, so `Pond.qml` sets the GL format (`0x881A`) at
  runtime to keep the half-float height field.
- **MultiEffect** (Qt 6.5) is replaced by `ShadowFx.qml` (blurred tinted shadow plus brightness)
  and `BlurFx.qml` (saturation plus blur), built on QtGraphicalEffects. The blur falloff is
  matched by eye, so glows can differ very slightly.
- **FrameAnimation** (Qt 6.4) is replaced by `FrameTicker.qml`, driven by the render loop.
- **QML / JS:** the fish moved from an inline component to `Koi.qml` (Qt 5.15 compiles inline
  component functions twice), optional chaining is rewritten, and the HUD and tank readout
  models look values up by name, since Qt 5 drops functions from array models.
- **Plasma APIs:** `WallpaperItem` becomes a plain `Item` reading `wallpaper.configuration`,
  `P5Support.DataSource` becomes `PlasmaCore.DataSource`, and imports are versioned.

## License

Code is GPL-3.0-or-later (`LICENSE`). The fish, water and caustic artwork is by MossyFish,
from [Still Waters](https://github.com/MossyFish/Still-Waters), and is CC BY-NC-SA 4.0
(`ART-LICENSE.md`). The bundled IBM Plex fonts are under the SIL Open Font License.
