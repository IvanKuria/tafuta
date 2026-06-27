#!/usr/bin/env python3
"""Generate the Tafuta semantic color tokens as an Xcode Asset Catalog.
Single source of truth for the Linear-inspired light/dark palette.
Run: python3 tools/gen_colors.py
"""
import json, os

ASSETS = os.path.join(os.path.dirname(__file__), "..", "app", "Resources", "Assets.xcassets")

# token: (light_hex, light_alpha, dark_hex, dark_alpha)
# Borders are opacity-based (white in dark / black in light) — the Linear trick.
# Raycast surface ladder (dark, from their design tokens) + a parallel designed light ladder.
TOKENS = {
    # Primary action = inverse ink (white-on-black dark / black-on-white light), like Raycast.
    "AccentColor":       ("#1D1D1F", 1.0,  "#F4F4F6", 1.0),
    "AccentFg":          ("#FFFFFF", 1.0,  "#07080A", 1.0),
    # Surface ladder: canvas → surface → elevated → inset(card). Depth via color, not shadow.
    "BgCanvas":          ("#F6F6F7", 1.0,  "#07080A", 1.0),
    "BgSurface":         ("#FFFFFF", 1.0,  "#0D0D0D", 1.0),
    "BgSurfaceElevated": ("#FFFFFF", 1.0,  "#101111", 1.0),
    "BgInset":           ("#ECECEE", 1.0,  "#121212", 1.0),  # active row / field / keycap fill
    "BorderSubtle":      ("#000000", 0.06, "#FFFFFF", 0.08),
    "BorderDefault":     ("#000000", 0.10, "#242728", 1.0),  # Raycast hairline
    "BorderStrong":      ("#000000", 0.16, "#FFFFFF", 0.16),
    "TextPrimary":       ("#1D1D1F", 1.0,  "#F4F4F6", 1.0),  # ink
    "TextSecondary":     ("#6E6E73", 1.0,  "#9C9C9D", 1.0),  # mute
    "TextTertiary":      ("#A1A1A6", 1.0,  "#6A6B6C", 1.0),  # ash
}

def comp(hex6, alpha):
    h = hex6.lstrip("#")
    return {"red": f"0x{h[0:2].upper()}", "green": f"0x{h[2:4].upper()}",
            "blue": f"0x{h[4:6].upper()}", "alpha": f"{alpha:.3f}"}

def colorset(light_hex, la, dark_hex, da):
    return {
        "colors": [
            {"idiom": "universal",
             "color": {"color-space": "srgb", "components": comp(light_hex, la)}},
            {"idiom": "universal",
             "appearances": [{"appearance": "luminosity", "value": "dark"}],
             "color": {"color-space": "srgb", "components": comp(dark_hex, da)}},
        ],
        "info": {"author": "xcode", "version": 1},
    }

def main():
    os.makedirs(ASSETS, exist_ok=True)
    with open(os.path.join(ASSETS, "Contents.json"), "w") as f:
        json.dump({"info": {"author": "xcode", "version": 1}}, f, indent=2)
    for name, vals in TOKENS.items():
        d = os.path.join(ASSETS, f"{name}.colorset")
        os.makedirs(d, exist_ok=True)
        with open(os.path.join(d, "Contents.json"), "w") as f:
            json.dump(colorset(*vals), f, indent=2)
    print(f"wrote {len(TOKENS)} colorsets to {os.path.normpath(ASSETS)}")

if __name__ == "__main__":
    main()
