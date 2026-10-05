# Submerge

A late-night koi pond for KDE Plasma 6, styled like a PS2-era game loading screen.

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

Needs KDE Plasma 6.

```sh
tar xzf submerge-1.6.tar.gz
cd submerge-1.6
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

Fish, water and caustic artwork by flyingf15h, from
[Still Waters](https://github.com/MossyFish/Still-Waters).
