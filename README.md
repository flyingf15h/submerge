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
  and, for the foreground fish, a saturation boost inside `glitch.frag`. Blurs run at reduced
  resolution in `SoftBlur.qml`; the falloff is matched by eye, so glows can differ very slightly.
- **FrameAnimation** (Qt 6.4) is replaced by `FrameTicker.qml`, driven by the render loop.
- **QML / JS:** the fish moved from an inline component to `Koi.qml` (Qt 5.15 compiles inline
  component functions twice), optional chaining is rewritten, and the HUD and tank readout
  models look values up by name, since Qt 5 drops functions from array models.
- **Plasma APIs:** `WallpaperItem` becomes a plain `Item` reading `wallpaper.configuration`,
  `P5Support.DataSource` becomes `PlasmaCore.DataSource`, and imports are versioned.

## Performance

Tuned to run on integrated graphics across two high-refresh screens. With the defaults it does
about a fifth of the GPU work of the first port, and nothing at all while paused. All of these
are under Performance in the wallpaper settings:

- **Frame rate limit** (default 10 fps). Plasma 5 redraws at the screen's refresh rate, which on
  a 144 or 165 Hz screen meant redrawing the whole pond ~150 times a second. The fish, the
  scanner, the HUD bars and the ripple simulation all advance on the same capped frames; the
  simulation does up to three steps per frame, on a half-resolution grid below 20 fps, so the
  ripples keep their speed.
- **Pause when covered** by a maximized or fullscreen window, per screen. Show Desktop counts as
  uncovered.
- **Still frame on battery.** Sensors and the clock drop to once a minute, so it costs about the
  same as a static wallpaper. Any paused screen does the same, and the `top`/`ps` polling stops.
- **Optional: only animate the screen in use** (off by default): the one with the focused window,
  its desktop clicked, or the pointer on its desktop; if that one is covered, the uncovered
  screens animate instead. Plasma 5 gives every screen its own window and GL context, so one
  rendered pond can't be mirrored to several screens.
- Glows are blurred at 1/4 resolution and the foreground fish at 1/8 (`SoftBlur.qml`), each
  foreground fish is a single full-screen pass, and the procedural caustics only cover the top
  third of the screen.

## Lock screen and sign-in screen

- **Lock screen:** in `~/.config/kscreenlockerrc` set `[Greeter] WallpaperPlugin=org.submerge.wallpaper`
  and `[Greeter][Wallpaper][org.submerge.wallpaper][General] LockScreen=true` (the lock screen
  hides every window, so the cover checks are skipped there). The Breeze lock screen UI is drawn
  on top.
- **Sign-in screen (SDDM):** from the release folder, `sudo sddm/install.sh` builds
  `/usr/share/sddm/themes/submerge` from the installed Breeze theme with the pond behind it (no
  HUD: its readouts need services that only run after login) and selects it in
  `/etc/sddm.conf.d/30-submerge-theme.conf`. Undo with `sudo sddm/install.sh --remove`.

## License

Code is GPL-3.0-or-later (`LICENSE`). The fish, water and caustic artwork is by MossyFish,
from [Still Waters](https://github.com/MossyFish/Still-Waters), and is CC BY-NC-SA 4.0
(`ART-LICENSE.md`). The bundled IBM Plex fonts are under the SIL Open Font License.
