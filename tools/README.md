# tools/

Python 3 + Pillow scripts used during the asset survey. They currently use absolute paths under
`/workspace/assets_survey` (the survey scratch dir on the shared box); change `A`/`OUT`/`S` at the top to point at `assets/` here.

| Script | What it does |
|---|---|
| `render.py` | Attack preview generator: `render(pack, char, [(name, frames)], fps=12, fsz=2)` → `<pack>_<char>_attacks.gif` (x3) + `_attack_sheet.png`; helpers `strip()` (sheet slicer) and `folder()` (natural-sorted frames). |
| `compat_lib.py` | Character registry, frame loading, union bounding boxes. |
| `compat.py` | Cemetery scene builder (`cemetery(W)`), feet-anchored `place()`. |
| `mockfight.py` | Builds the mock fight GIFs with native per-frame timings. |
| `merakintsugi_compat.py` | Lineup/close-up for the merakintsugi sample heroine. |
| `kira_compat.py` | Sprite Kitchen Kira proofs (scale mismatch, lineups, close-up). |
| `dl2.py` | Downloads **free** itch.io files without login: `python3 dl2.py <outdir> <itch game urls...>` (never pays or signs in). |
| `ase_render.py` | Minimal `.aseprite` reader/compositor (RGBA, layers incl. groups/visibility, linked + compressed cels, tags, durations). `load(path)`, `frame(a, i, only={layers})`. |
| `ase_info.py` | Prints frames / canvas / durations / layers / tags for every `.aseprite` under the cwd. |
| `mk_full.py` | merakintsugi full-pack audit (baseline, edge clipping, palette, chain alignment via FFT) + combo GIFs and full attack sheet: `python3 mk_full.py <pack_dir> <out_dir>`. |
| `hero_lineup.py` | Hero-anchored lineups (raw / palette-harmonised), x4 close-up and mock fight GIF on the 384×216 Cemetery view. |
