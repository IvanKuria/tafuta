#!/usr/bin/env python3
"""Generate the Tafuta semantic color tokens as an Xcode Asset Catalog.
Single source of truth for the Linear-inspired light/dark palette.
Run: python3 tools/gen_colors.py
"""
import json, os

ASSETS = os.path.join(os.path.dirname(__file__), "..", "app", "Resources", "Assets.xcassets")

# token: (light_hex, light_alpha, dark_hex, dark_alpha)
# Borders are opacity-based (white in dark / black in light) — the Linear trick.
TOKENS = {
    "AccentColor":       ("#2F6FED", 1.0,  "#5E8CF0", 1.0),
    "BgCanvas":          ("#FBFBFB", 1.0,  "#08090A", 1.0),
    "BgSurface":         ("#FFFFFF", 1.0,  "#0F1011", 1.0),
    "BgSurfaceElevated": ("#FFFFFF", 1.0,  "#161719", 1.0),
    "BgInset":           ("#F4F5F6", 1.0,  "#0B0C0D", 1.0),
    "BorderSubtle":      ("#000000", 0.06, "#FFFFFF", 0.06),
    "BorderDefault":     ("#000000", 0.10, "#FFFFFF", 0.10),
    "BorderStrong":      ("#000000", 0.16, "#FFFFFF", 0.16),
    "TextPrimary":       ("#16171A", 1.0,  "#F7F8F8", 1.0),
    "TextSecondary":     ("#5C5F66", 1.0,  "#9CA0A8", 1.0),
    "TextTertiary":      ("#8A8D93", 1.0,  "#62666D", 1.0),
    "AccentFg":          ("#FFFFFF", 1.0,  "#0B0C0D", 1.0),
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
