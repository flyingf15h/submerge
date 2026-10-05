# KDE Store listing for Submerge

Published 2026-10-05 under flyingf15h:
- Wallpaper: https://store.kde.org/p/2377252/
- Plasma style: https://store.kde.org/p/2377258/
- Colour scheme: https://store.kde.org/p/2377259/
- Global theme: https://store.kde.org/p/2377260/

To ship an update, edit each product (Products > Edit), bump the version, upload the new file on
the Files step and add a changelog entry.

Four items at https://store.kde.org (log in, then "Add Product"). Upload the global theme last so
it can link to the other three. Files are in `dist/store/` after `./build-dist.sh`, screenshots in
`store/screenshots/` (`submerge-preview.gif` is the animated one for the gallery).

---

## 1. Wallpaper

- **Category:** Plasma 6 Add-Ons > Plasma 6 Wallpaper Plugins
- **Title:** Submerge
- **File:** `dist/store/submerge-wallpaper-1.6.tar.gz`
- **License:** GPLv3
- **Tags:** koi, fish, aquarium, water, animated, live wallpaper, hud, dark, blue
- **Summary:** Koi swimming in a dark pond, with a HUD for your clock and system stats

**Description:**

Koi swimming around a dark pond at night, with a HUD that shows the time, CPU, GPU, memory,
network, storage and battery.

The fish are hand painted and swim the way koi do, in short bursts and long glides. Ripples come
from a small water simulation, so drips and fish coming up to the surface leave real rings. Hover
over a fish and a specimen box locks onto it.

The tank's temperature, pH and oxygen change every time you boot, and they decide which koi
varieties show up most.

It runs at 20 fps, drops to 10 while you're in a window, stops when a maximized window covers
it, and holds a still frame on battery while you use a window so it costs no extra power. Every effect can be turned off in the wallpaper settings. Works on the lock
screen too.

Needs Plasma 6. Art by flyingf15h (CC BY-NC-SA 4.0), code GPLv3.
Source: https://github.com/flyingf15h/submerge

**Changelog (1.6):** Hovering over a fish works again, it keeps swimming on battery when no windows are open, the battery row shows how much time is left, and it does less work per frame.

**Changelog (1.3):** Ripples keep their speed at low frame rates, battery row in the HUD, lock and
sign-in screen support.

---

## 2. Plasma style (panel and taskbar)

- **Category:** Plasma 6 Add-Ons > Plasma Themes
- **Title:** Submerge
- **File:** `dist/store/submerge-plasma-style-1.6.tar.gz`
- **License:** GPLv3
- **Tags:** dark, blue, navy, glass, panel, taskbar
- **Summary:** Dark glass panel with a glowing edge

**Description:**

A see-through navy panel with a thin glowing top edge. The app you're using gets a bright blue
line under it, other open apps get a dim one, and anything asking for attention turns orange.

Made for the Submerge wallpaper, but it works fine on its own.

**Changelog (1.3):** The panel is now see-through glass.

---

## 3. Colour scheme

- **Category:** Plasma 6 Add-Ons > Plasma Color Schemes
- **Title:** Submerge
- **File:** `dist/store/Submerge.colors`
- **License:** GPLv3
- **Tags:** dark, blue, navy, orange
- **Summary:** Deep navy with electric blue highlights

**Description:**

Deep navy windows, pale blue text and electric blue selections, with orange for warnings and
visited links. Matches the Submerge wallpaper.

**Changelog (1.3):** First release.

---

## 4. Global theme

- **Category:** Plasma 6 Add-Ons > Global Themes (Plasma 6)
- **Title:** Submerge
- **File:** `dist/store/submerge-global-theme-1.6.tar.gz` (also attach `dist/submerge-1.6.tar.gz`)
- **License:** GPLv3
- **Tags:** koi, fish, aquarium, dark, blue, hud, animated
- **Summary:** A night koi pond desktop, styled like an old game loading screen

**Description:**

Sets up the whole Submerge look at once: the koi pond wallpaper, the glass panel, the colour
scheme and a matching splash screen.

Install these first, or applying the theme won't find them:
- Wallpaper: https://store.kde.org/p/2377252/
- Plasma style: https://store.kde.org/p/2377258/
- Colour scheme: https://store.kde.org/p/2377259/

Or download submerge-1.6.tar.gz from this page and run ./install.sh --apply, which installs
everything in one go. The download also has an optional sign-in screen.

Art by flyingf15h (CC BY-NC-SA 4.0), code GPLv3.
Source: https://github.com/flyingf15h/submerge

**Changelog (1.3):** First release on the store.
