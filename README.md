# Submerge

A late night koi pond for KDE Plasma 6, styled like an old game loading screen.

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

From the KDE Store: [global theme](https://store.kde.org/p/2377260/),
[wallpaper](https://store.kde.org/p/2377252/), [panel style](https://store.kde.org/p/2377258/),
[colour scheme](https://store.kde.org/p/2377259/). Or the all-in-one download:


Grab `submerge-1.5.tar.gz` from [Releases](../../releases), then:

```sh
tar xzf submerge-1.5.tar.gz
cd submerge-1.5
./install.sh --apply
```

Without `--apply` it only installs; pick **Submerge** under System Settings > Colours & Themes >
Global Theme. `./uninstall.sh` removes it. Needs Plasma 6.

## From source

```sh
./install.sh        # recompiles shaders (needs uv) and installs the wallpaper
./preview.py        # live preview window that restarts whenever a file changes
./build-dist.sh     # builds dist/submerge-<version>.tar.gz and the KDE Store archives
```

`prep.py` regenerates the tinted fish and water images from the original art, and
`plasma-style/build.py` builds the panel style.

## Lock screen and sign-in screen

The wallpaper works on the lock screen too. Pick **Submerge** under System Settings >
Screen Locking > Appearance, or run:

```sh
kwriteconfig6 --file kscreenlockerrc --group Greeter --key WallpaperPlugin org.submerge.wallpaper
kwriteconfig6 --file kscreenlockerrc --group Greeter --group Wallpaper --group org.submerge.wallpaper --group General --key LockScreen true
```

For the sign-in screen (SDDM), the release has an `sddm` folder with Breeze's login form over
the pond. It installs system-wide, so it needs sudo:

```sh
cd submerge-1.5/sddm
sudo ./install.sh            # undo with: sudo ./install.sh --remove
```

## Plasma 5

[darshg321](https://github.com/darshg321) ported Submerge to Plasma 5.27 on the
[`plasma5` branch](../../tree/plasma5), and came up with the frame rate cap, multi-step ripples,
battery readout and lock / sign-in screens that this version now uses too.

## License

Code is GPL-3.0-or-later (`LICENSE`). The fish, water and caustic artwork is by flyingf15h,
from [Still Waters](https://github.com/MossyFish/Still-Waters), and is CC BY-NC-SA 4.0
(`ART-LICENSE.md`). The bundled IBM Plex fonts are under the SIL Open Font License.
