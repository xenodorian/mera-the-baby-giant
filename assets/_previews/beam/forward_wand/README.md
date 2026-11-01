# Mera: frames where her wand points FORWARD
All 33 .aseprite files were scanned (547 character-layer frames, fx/illusion/smoke layers excluded) by
`tools/forward_wand_detect.py` (finds the wand by its colours #2f1850 / #59454d / #a64b0a, fits its axis), then every
candidate was checked by eye. PNGs: 6x nearest-neighbour, flipped to face RIGHT, red tick just past the wand tip
(outside the sprite). Angle: + = tip up, - = tip down, relative to horizontal-forward. Made by `tools/forward_wand_candidates.py`.
Frame numbers are 0-based (1-based in brackets on each label). `candidates.json` has the tip coordinates and pixel
differences to neighbouring frames (how stable the pose is).
