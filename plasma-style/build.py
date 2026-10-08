#!/usr/bin/env python3
"""Builds the "Submerge" Plasma style (panel + task manager look) into the given folder, or
installs it to ~/.local/share/plasma/desktoptheme/submerge when no folder is given. Anything not drawn here falls back to the
default Plasma style, coloured by the Submerge colour scheme."""
import gzip, json, os, shutil

import sys
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.expanduser("~/.local/share/plasma/desktoptheme/submerge")
HERE = os.path.dirname(os.path.abspath(__file__))

BLUE, PALE, HOT = "#5d8dff", "#9fbaff", "#ff8a3d"

def svg(w, h, body):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">\n'
            f'<defs><linearGradient id="panelfill" x1="0" y1="0" x2="0" y2="1">'
            f'<stop offset="0" stop-color="#0a1838"/><stop offset="1" stop-color="#030918"/></linearGradient>'
            f'<linearGradient id="edgeglow" x1="0" y1="0" x2="0" y2="1">'
            f'<stop offset="0" stop-color="{BLUE}" stop-opacity="0.35"/><stop offset="1" stop-color="{BLUE}" stop-opacity="0"/></linearGradient>'
            f'</defs>\n{body}</svg>\n')

def write(rel, text):
    for sub in ("widgets", "translucent/widgets", "opaque/widgets") if rel == "panel-background" else ("widgets",):
        path = os.path.join(OUT, sub, rel + ".svgz")
        os.makedirs(os.path.dirname(path), exist_ok=True)
        # the translucent panel is glass over the pond: mostly see-through, blurred behind by KWin
        t = text if sub != "translucent/widgets" else text.replace('fill-opacity="0.92"', 'fill-opacity="0.42"')
        with gzip.open(path, "wt") as f:
            f.write(t)

# ---------- panel: navy glass, a glowing top edge, little corner brackets ----------
def panel():
    c, W = 8, 80   # corner size, centre size; laid out in a 3x3 grid
    x = [0, c, c + W]; y = [0, c, c + W]; ws = [c, W, c]
    names = [["topleft", "top", "topright"], ["left", "center", "right"], ["bottomleft", "bottom", "bottomright"]]
    parts = []
    for r in range(3):
        for col in range(3):
            n = names[r][col]
            X, Y, w, h = x[col], y[r], ws[col], ws[r]
            g = f'<g id="{n}">'
            g += f'<rect x="{X}" y="{Y}" width="{w}" height="{h}" fill="url(#panelfill)" fill-opacity="0.92"/>'
            if r == 0:   # glowing top edge
                g += f'<rect x="{X}" y="{Y}" width="{w}" height="{h}" fill="url(#edgeglow)"/>'
                g += f'<rect x="{X}" y="{Y}" width="{w}" height="1" fill="{PALE}" fill-opacity="0.75"/>'
            if n in ("topleft", "topright"):   # bracket ticks at the ends
                bx = X + 1 if n == "topleft" else X + w - 2
                g += f'<rect x="{bx}" y="{Y + 1}" width="1" height="{c - 2}" fill="{PALE}" fill-opacity="0.9"/>'
            g += '</g>\n'
            parts.append(g)
            parts.append(f'<rect id="mask-{n}" x="{X}" y="{Y + 2 * (c + W + c)}" width="{w}" height="{h}" fill="#000"/>\n')
    for side, v in (("top", 6), ("bottom", 4), ("left", 8), ("right", 8)):
        parts.append(f'<rect id="hint-{side}-margin" x="0" y="{-20}" width="{v}" height="{v}" fill="none"/>\n')
    return svg(c + W + c, 3 * (c + W + c), "".join(parts))

# ---------- task buttons: indicator lines that glow, tinted backgrounds ----------
STATES = {
    #           tint colour, tint opacity, line colour, line opacity, line width, glow
    "normal":    (BLUE, 0.0,  PALE, 0.45, 2, False),
    "hover":     (BLUE, 0.14, PALE, 0.8,  2, True),
    "focus":     (BLUE, 0.24, PALE, 1.0,  3, True),
    "attention": (HOT,  0.18, HOT,  1.0,  3, True),
    "minimized": (BLUE, 0.0,  PALE, 0.22, 1, False),
    "progress":  (BLUE, 0.3,  BLUE, 0.9,  2, False),
}
# which edge the indicator sits on, per panel edge (no prefix = bottom panel)
EDGES = {"": "bottom", "north-": "top", "west-": "left", "east-": "right"}

def tasks():
    c, W = 6, 40
    parts, oy = [], 0
    for state, (tint, ta, line, la, lw, glow) in STATES.items():
        for prefix, edge in EDGES.items():
            x = [0, c, c + W]; y = [oy, oy + c, oy + c + W]; ws = [c, W, c]
            names = [["topleft", "top", "topright"], ["left", "center", "right"], ["bottomleft", "bottom", "bottomright"]]
            for r in range(3):
                for col in range(3):
                    n = names[r][col]
                    X, Y, w, h = x[col], y[r], ws[col], ws[r]
                    g = f'<g id="{prefix}{state}-{n}"><rect x="{X}" y="{Y}" width="{w}" height="{h}" fill="{tint}" fill-opacity="{ta}"/>'
                    on_edge = (edge == "bottom" and r == 2) or (edge == "top" and r == 0) or \
                              (edge == "left" and col == 0) or (edge == "right" and col == 2)
                    if on_edge:
                        if edge in ("bottom", "top"):
                            ly = Y + h - lw if edge == "bottom" else Y
                            gy = Y if edge == "bottom" else Y + lw
                            if glow:
                                g += f'<rect x="{X}" y="{gy}" width="{w}" height="{h - lw}" fill="{line}" fill-opacity="0.18"/>'
                            g += f'<rect x="{X}" y="{ly}" width="{w}" height="{lw}" fill="{line}" fill-opacity="{la}"/>'
                        else:
                            lx = X if edge == "left" else X + w - lw
                            gx = X + lw if edge == "left" else X
                            if glow:
                                g += f'<rect x="{gx}" y="{Y}" width="{w - lw}" height="{h}" fill="{line}" fill-opacity="0.18"/>'
                            g += f'<rect x="{lx}" y="{Y}" width="{lw}" height="{h}" fill="{line}" fill-opacity="{la}"/>'
                    parts.append(g + '</g>\n')
            oy += c + W + c + 4
    for side in ("top", "bottom", "left", "right"):
        parts.append(f'<rect id="normal-hint-{side}-margin" x="0" y="{oy}" width="4" height="4" fill="none"/>\n')
    oy += 8
    # small arrows shown on grouped tasks
    arrows = {"bottom": "M0,0 L8,0 L4,4 Z", "top": "M0,4 L8,4 L4,0 Z", "left": "M4,0 L4,8 L0,4 Z", "right": "M0,0 L0,8 L4,4 Z"}
    for i, (d, p) in enumerate(arrows.items()):
        parts.append(f'<path id="group-expander-{d}" transform="translate({i * 12},{oy})" d="{p}" fill="{PALE}" fill-opacity="0.8"/>\n')
    return svg(c + W + c + 40, oy + 12, "".join(parts))

def main():
    shutil.rmtree(OUT, ignore_errors=True)
    os.makedirs(OUT)
    write("panel-background", panel())
    write("tasks", tasks())
    shutil.copy(os.path.join(HERE, "colors"), os.path.join(OUT, "colors"))
    with open(os.path.join(OUT, "plasmarc"), "w") as f:
        f.write("[ContrastEffect]\nenabled=true\ncontrast=0.8\nintensity=1.0\nsaturation=1.5\n\n[AdaptiveTransparency]\nenabled=true\n")
    meta = {"KPlugin": {"Id": "submerge", "Name": "Submerge", "Description": "Night-aquarium panel to match the Submerge wallpaper",
                        "Authors": [{"Name": "flyingf15h"}], "License": "GPL-3.0-or-later", "Version": "1.0", "EnabledByDefault": True},
            "X-Plasma-API": "5.0"}
    with open(os.path.join(OUT, "metadata.json"), "w") as f:
        json.dump(meta, f, indent=4)
    print("installed", OUT)

main()
