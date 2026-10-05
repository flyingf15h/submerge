# Submerge

A late-night koi pond for KDE Plasma 5, styled like a PS2-era game loading screen.

![screenshot](look-and-feel/org.submerge.desktop/contents/previews/fullscreenpreview.jpg)

## What's included

- **Live wallpaper**: koi and goldfish that swim in bursts and glides, a real water simulation
  for ripples, light caustics along the top, and two or three big blurry glitching goldfish
  drifting past the glass.
- **HUD**: big clock, live CPU / GPU / memory / network / storage readouts, system status.
- **Tank monitor**: brackets that lock onto fish (and follow your cursor), a depth ruler,
  and tank conditions that are rerolled every time you boot. The conditions decide which
  fish thrive: warm water brings out goldfish, acidic water teal koi, alkaline water violet
  koi, and low oxygen more juveniles.
- **Plasma style** for the panel and task manager, a matching **colour scheme**, and a
  **splash screen**.
- IBM Plex Mono and IBM Plex Sans Condensed fonts (SIL Open Font License).

## Install

Needs KDE Plasma 5.27.

```sh
tar xzf submerge-1.0-plasma5.tar.gz
cd submerge-1.0-plasma5
./install.sh --apply
```

Without `--apply` it just installs; pick **Submerge** under
System Settings > Colours & Themes > Global Theme. Tick "Desktop and window layout" there if
you also want the wallpaper switched automatically, or choose **Submerge** under
Desktop Wallpaper.

Wallpaper settings (right-click the desktop > Configure Desktop and Wallpaper) let you change
the number of fish, size, speed, title, user name, and turn off any of the effects.

## Remove

```sh
./uninstall.sh
```

## Credits

Fish, water and caustic artwork by MossyFish, from
[Still Waters](https://github.com/MossyFish/Still-Waters).

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
