"""Looping cemetery map for the playable level (assets/environments/ansimuz/gothicvania-cemetery/loop/).
Same layout as scripts/stage.gd (native 384 x 216, x5 = 1920 x 1080, feet line at native y 212), split in two
parallax layers. Each layer repeats every 384 px; the seam is hidden by a blurred cross-fade: the band
around the wrap point is blended with a Gaussian-blurred copy (weight 1 at the seam, 0 at +-SEAM px).
The ansimuz source PNGs are only read."""
import os
import numpy as np
from PIL import Image, ImageFilter
SRC = 'assets/environments/ansimuz/gothicvania-cemetery'; OUT = f'{SRC}/loop'; W, H, SH = 384, 216, 24; SEAM = 20
def tiled(canvas, im, y):
    for x in range(0, W, im.width): canvas.alpha_composite(im, (x, y))
bg = Image.open(f'{SRC}/background.png').convert('RGBA'); mt = Image.open(f'{SRC}/mountains.png').convert('RGBA')
gy = Image.open(f'{SRC}/graveyard.png').convert('RGBA'); tile = Image.open(f'{SRC}/tileset.png').convert('RGBA').crop((64, 48, 128, 96))
far = Image.new('RGBA', (W, H), (0, 0, 34, 255)); tiled(far, bg, SH); tiled(far, mt, 224 - mt.height - 30 + SH)
near = Image.new('RGBA', (W, H), (0, 0, 0, 0)); tiled(near, gy, 224 - gy.height - 20 + SH)
tiled(near, tile, 172 + SH)   # ground row (the stage's dirt fill starts below the 216 px screen)
def seam_blur(im, r=2.2):
    a = np.array(im).astype(float); t = np.concatenate([a, a, a], 1)
    pm = t.copy(); pm[..., :3] *= pm[..., 3:4] / 255           # premultiplied blur so transparent pixels don't darken
    b = np.array(Image.fromarray(pm.astype(np.uint8)).filter(ImageFilter.GaussianBlur(r))).astype(float)
    ba = np.array(Image.fromarray(t[..., 3].astype(np.uint8)).filter(ImageFilter.GaussianBlur(r))).astype(float)
    b[..., 3] = ba; nz = ba > 0; b[nz, :3] = np.clip(b[nz, :3] * 255 / ba[nz, None], 0, 255)
    # inside the band (wrapped image, so both map ends meet) the blurred copy takes over, strongest at the seam
    x = np.arange(3 * W); dist = np.minimum(np.abs(x - W), np.abs(x - 2 * W)); w = np.clip(1 - dist / SEAM, 0, 1)[None, :, None]
    out = t * (1 - w) + b * w
    return Image.fromarray(np.clip(out[:, W:2 * W], 0, 255).astype(np.uint8))
os.makedirs(OUT, exist_ok=True)
seam_blur(far).save(f'{OUT}/far_loop.png'); seam_blur(near).save(f'{OUT}/near_loop.png')
check = Image.new('RGBA', (W * 2, H)); check.alpha_composite(seam_blur(far), (0, 0)); check.alpha_composite(seam_blur(far), (W, 0))
check.alpha_composite(seam_blur(near), (0, 0)); check.alpha_composite(seam_blur(near), (W, 0)); check.save('/tmp/loopcheck.png')
print('ok')
