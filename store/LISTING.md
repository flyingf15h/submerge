# KDE Store listing for Submerge (Plasma 5)

Published under flyingf15h. The Plasma 5 items share the Plasma 6 pages where the store allows it:
- Plasma 5 wallpaper: https://store.kde.org/p/2377369/
- Plasma 5 global theme: https://store.kde.org/p/2377371/
- Plasma style: https://store.kde.org/p/2377258/ (shared with Plasma 6; the Plasma 5 build is the
  `-plasma5` file there, and it **must be tagged Plasma 5** on the Files step, because Plasma 5's
  "Get New Plasma Styles" only lists files tagged `plasma##version==5`)
- Colour scheme: https://store.kde.org/p/2377259/ (shared; the same `Submerge.colors` works on both)

Versions match the Plasma 6 releases on `main`, so 1.8 here has the same features as 1.8 there.

To ship an update, edit each product (Products > Edit), bump the version, upload the new file on
the Files step (replacing the old -plasma5 file, not the Plasma 6 one) and add a changelog entry.
Files are in `dist/store/` after `./build-dist.sh`, screenshots in `store/screenshots/` (gallery
order: `submerge-preview.gif`, `submerge-1.jpg`, `submerge-lockscreen.jpg`; the store caps
pictures at 5MB) and logos in `store/logos/`.

---

## 1. Wallpaper

- **Category:** Plasma 5 Add-Ons > Plasma 5 Wallpaper Plugins
- **Title:** Submerge
- **File:** `dist/store/submerge-wallpaper-1.8-plasma5.tar.gz`
- **License:** GPLv3 (artwork CC BY-NC-SA 4.0, mention in the description)
- **Tags:** koi, fish, aquarium, water, animated, live wallpaper, cyberpunk, hud, dark, blue
- **Summary:** A late night koi pond with a sci-fi tank monitor HUD

**Description:**

Koi drift around a dark blue pond at night, lit from above with soft caustic light, while a tank
monitor HUD keeps an eye on them and on your computer.

What's in it:

- Hand drawn koi that swim in bursts and glides and bend into their turns
- Real ripples from a small water simulation, from drips, rising fish and your cursor
- Two or three big blurry koi drifting past the glass with a slight glitch
- A HUD with a big clock and live CPU, GPU, memory, network and storage readouts, including which app is using the most CPU and memory
- A specimen box that locks onto whichever fish is closest to your cursor, with its koi variety, heading and depth
- Tank conditions (temperature, pH, oxygen, flow) that change every time you boot, and change which koi varieties show up the most

Everything can be turned off or tuned in the wallpaper settings: number of fish, size, speed, text size, title, user name, ripples, light, grain and the HUD.

Needs Plasma 5. For the full look, also grab the Submerge global theme, Plasma style and colour scheme.

Fish artwork by MossyFish, licensed CC BY-NC-SA 4.0. Code is GPLv3. Source: https://github.com/flyingf15h/submerge

**Changelog (1.8):** Version numbers now match the Plasma 6 releases. Koi swim more like real fish: turns bend the whole body in one smooth curve, a wave runs down the body, and the tail and fins trail, sweep back and flutter. The big blurry fish turn gently. Soft patches of golden sun and shade drift through the water, the colour varies a little from place to place, and the top of the screen is no longer washed out grey. The lock screen says when the laptop is charging or plugged in. Slightly less work per frame.

**Changelog (1.0):** First release.

---

## 2. Plasma style (panel and taskbar)

- **Category:** Plasma 5 Add-Ons > Plasma Themes
- **Title:** Submerge
- **File:** `dist/store/submerge-plasma-style-1.8-plasma5.tar.gz` (tag it Plasma 5)
- **License:** GPLv3
- **Tags:** dark, blue, navy, cyberpunk, hud, panel, taskbar
- **Summary:** Navy glass panel with a glowing edge, made for the Submerge wallpaper

**Description:**

A dark navy panel with a thin glowing top edge and small corner brackets. The focused app gets a
blue glow and a bright line under it, other open apps get a dim line, and apps asking for your
attention light up orange. Everything else uses the default Plasma style, coloured with the
Submerge colour scheme.

Made to go with the Submerge wallpaper, but it works fine on its own.

**Changelog (1.8):** Version numbers now match the Plasma 6 releases. No visual changes.

**Changelog (1.0):** First release.

---

## 3. Colour scheme

- **Category:** Plasma 5 Add-Ons > Plasma Color Schemes
- **Title:** Submerge
- **File:** `dist/store/Submerge.colors`
- **License:** GPLv3
- **Tags:** dark, blue, navy, orange, cyberpunk
- **Summary:** Deep navy with electric blue highlights and orange accents

**Description:**

Deep navy windows, pale blue text, electric blue selections and warm orange for links you've
visited and things that need attention. Made for the Submerge wallpaper.

**Changelog (1.0):** First release.

---

## 4. Global theme

- **Category:** Plasma 5 Add-Ons > Global Themes (Plasma 5)
- **Title:** Submerge
- **File:** `dist/store/submerge-global-theme-1.8-plasma5.tar.gz` (also attach `dist/submerge-1.8-plasma5.tar.gz`)
- **License:** GPLv3
- **Tags:** koi, fish, aquarium, dark, blue, cyberpunk, hud, animated
- **Summary:** A late night koi pond desktop, styled like an old game loading screen

**Description:**

Turns your desktop into a late night aquarium. Applies the Submerge wallpaper, Plasma style,
colour scheme and a matching splash screen in one go.

This theme uses three other items, so install those first (or use the all-in-one download on GitHub):

- Submerge wallpaper (Plasma 5): https://store.kde.org/p/2377369/
- Submerge Plasma style (take the -plasma5 file): https://store.kde.org/p/2377258/
- Submerge colour scheme: https://store.kde.org/p/2377259/

Tick "Desktop and window layout" when applying it if you want the wallpaper switched for you.

Or download submerge-1.8-plasma5.tar.gz from this page and run ./install.sh --apply, which installs
everything in one go. The download also has an optional sign-in screen.

Fish artwork by MossyFish, licensed CC BY-NC-SA 4.0. Code is GPLv3.

**Changelog (1.8):** Version numbers now match the Plasma 6 releases. Includes wallpaper 1.8: more natural swimming, sun and shade in the water, and the lock screen shows when the laptop is charging or plugged in.

**Changelog (1.0):** First release.
