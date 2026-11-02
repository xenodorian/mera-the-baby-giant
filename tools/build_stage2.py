#!/usr/bin/env python3
"""Build the five Perry stage 2 levels and append them to assets/levels/levels.json.

Each level gets assets/levels/<id>/{sky,ground,fringe,thumb}.png. Entries are appended
after the existing levels (an entry with the same id is replaced in place). The
existing entries are not touched. Layer geometry follows game.gd: art scale x5,
period = native width * 5, screen 1920 x 1080, camera x 0.
"""
import json
import shutil
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
LEVELS_JSON = ROOT / "assets" / "levels" / "levels.json"
BGS = ROOT / "assets" / "perry" / "maps" / "bgs"

ART = 5
SCREEN_W, SCREEN_H = 1920, 1080
GROUND_Y = 100  # ground row 191 lands at game y 1055, same as the country ground
SKY_Y = -40
SKY_PAD = (GROUND_Y - SKY_Y) // ART   # 28 rows: puts sky row 0 at the ground layer's row 0
SKY_SCROLL = 0.12
GROUND_Z, FRINGE_Z, SKY_Z = -10, -9, -40

LEVELS = [
    ("p_falls", "Mossy Falls", "Goblins under the waterfalls", "falls", "level2.ogg"),
    ("p_canyon", "Sunstone Canyon", "Red cliffs and raiders", "canyon", "level3.ogg"),
    ("p_shore", "Sunset Shore", "A calm beach with a bad crowd", "shore", "level4.ogg"),
    ("p_mire", "Mire Wood", "Hot, wet and crowded", "mire", "level5.ogg"),
    ("p_sanctum", "Moonlit Sanctum", "Perry waits at the center of the island", "sanctum", "level6.ogg"),
]


def res_path(res: str) -> Path:
    assert res.startswith("res://"), res
    return ROOT / res[len("res://"):]


def first_opaque_row(img: Image.Image) -> int:
    alpha = np.asarray(img.convert("RGBA"))[:, :, 3]
    rows = np.where(alpha.max(axis=1) > 0)[0]
    return int(rows[0])


def build_layers(level_id: str, theme: str) -> list:
    base = f"res://assets/levels/{level_id}/"
    sky = Image.open(BGS / f"{theme}_sky.png")
    ground = Image.open(BGS / f"{theme}_ground.png")
    fringe = Image.open(BGS / f"{theme}_fringe.png")
    sky_period = sky.width * ART  # sky widths differ per theme
    ground_period = ground.width * ART  # 384 * 5 = 1920
    fringe_period = fringe.width * ART

    # Fringe grass starts at native row first_opaque_row(fringe). With y = GROUND_Y it would
    # start at game y 100 + 5 * 222 = 1210, below the 1080 screen, so it is moved to put the
    # bottom of the strip on the bottom screen edge (y = 1080 - 232 * 5 = -80).
    fringe_y = GROUND_Y
    if fringe_y + ART * first_opaque_row(fringe) >= SCREEN_H:
        fringe_y = SCREEN_H - fringe.height * ART

    return [
        {"file": base + "sky.png", "scroll": SKY_SCROLL, "y": SKY_Y, "z": SKY_Z,
         "period": sky_period, "w": sky_period, "modulate": None},
        {"file": base + "ground.png", "scroll": 1.0, "y": GROUND_Y, "z": GROUND_Z,
         "period": ground_period, "w": ground_period, "modulate": None},
        {"file": base + "fringe.png", "scroll": 1.0, "y": fringe_y, "z": FRINGE_Z,
         "period": fringe_period, "w": fringe_period, "modulate": None},
    ]


def sky_top_colour(theme: str) -> list:
    sky = np.asarray(Image.open(BGS / f"{theme}_sky.png").convert("RGB"))
    mean = sky[:8].reshape(-1, 3).mean(axis=0)
    return [int(round(float(c))) for c in mean]


def compose(bg, layers, pad: float) -> np.ndarray:
    """Render the first screen (camera x 0) the way game.gd places layers. Returns H x W x 3 uint8."""
    canvas = np.zeros((SCREEN_H, SCREEN_W, 3), dtype=np.float64)
    canvas[:] = np.asarray(bg, dtype=np.float64)
    xs = np.arange(SCREEN_W)
    ys = np.arange(SCREEN_H)
    pos_x = -960 - int(pad)  # game.gd: cam_x - 960 - pad, with cam_x = 0 and fposmod(0) = 0
    for L in sorted(layers, key=lambda layer: layer["z"]):
        tex = np.asarray(Image.open(res_path(L["file"])).convert("RGBA"))
        th, tw = tex.shape[:2]
        period = float(L["period"])
        pos_y = float(L["y"])
        cols = (xs - pos_x) // ART
        if period > 0.0:
            assert period == tw * ART, (L["file"], period, tw)
            cols = cols % tw  # texture repeats at its native width
            col_ok = np.ones_like(cols, dtype=bool)
        else:
            col_ok = (cols >= 0) & (cols < tw)
        rows = (ys - int(pos_y)) // ART
        row_ok = (rows >= 0) & (rows < th)
        src = tex[np.clip(rows, 0, th - 1)[:, None], np.clip(cols, 0, tw - 1)[None, :]]
        valid = row_ok[:, None] & col_ok[None, :]
        a = (src[:, :, 3:4] / 255.0) * valid[:, :, None]
        canvas = canvas * (1.0 - a) + src[:, :, :3] * a
    return np.clip(np.round(canvas), 0, 255).astype(np.uint8)


def main() -> None:
    raw = LEVELS_JSON.read_text()
    doc = json.loads(raw)
    pad = float(doc["pad"])
    existing_ids = [lv["id"] for lv in doc["levels"]]

    for level_id, name, sub, theme, music in LEVELS:
        dest = ROOT / "assets" / "levels" / level_id
        dest.mkdir(parents=True, exist_ok=True)
        for part in ("sky", "ground", "fringe"):
            if part == "sky":
                # Perry draws sky and ground as one 232-row frame, so the sky moves down with the ground (y 100).
                # a mirrored copy of its top SKY_PAD rows goes above it, so it still starts at SKY_Y and fills the top of the screen.
                src = Image.open(BGS / f"{theme}_sky.png").convert("RGBA")
                out = Image.new("RGBA", (src.width, src.height + SKY_PAD))
                out.paste(src.crop((0, 0, src.width, SKY_PAD)).transpose(Image.FLIP_TOP_BOTTOM), (0, 0))
                out.paste(src, (0, SKY_PAD))
                out.save(dest / "sky.png")
                continue
            shutil.copyfile(BGS / f"{theme}_{part}.png", dest / f"{part}.png")

        layers = build_layers(level_id, theme)
        bg = sky_top_colour(theme)
        music_res = f"res://assets/perry/music/{music}"
        assert res_path(music_res).is_file(), music_res
        entry = {"id": level_id, "name": name, "sub": sub, "layers": layers,
                 "bg": bg, "music": music_res}

        frame = compose(bg, layers, pad)
        # Native-scale thumb: sample the centre of each x5 game pixel, giving 384 x 216.
        thumb = frame[2::ART, 2::ART]
        assert thumb.shape == (216, 384, 3), thumb.shape
        Image.fromarray(thumb).save(dest / "thumb.png")

        if level_id in existing_ids:
            doc["levels"][existing_ids.index(level_id)] = entry
        else:
            doc["levels"].append(entry)
            existing_ids.append(level_id)

    for lv in doc["levels"]:
        for L in lv["layers"]:
            assert res_path(L["file"]).is_file(), L["file"]
        assert res_path(lv["music"]).is_file(), lv["music"]

    # Matches the existing file: json.dumps with indent=1 and no trailing newline.
    LEVELS_JSON.write_text(json.dumps(doc, indent=1))
    print(f"levels: {len(doc['levels'])}")


if __name__ == "__main__":
    main()
