# Wand beam from the user's three picked frames
Matched by colour-correlation of the user's screenshots (rescaled to 1x) against all 547 character-layer frames
(match = share of the screenshot's pixels reproduced exactly at the best offset).
| Pick | Source (0-based frame) | Match | Wand tip (native canvas px) | Wand points | Held |
|---|---|---|---|---|---|
| 1 | `atk/3x atk/3x atk.aseprite`, layer `3x atk`, f24 | 100.0% | (162, 72) = LEFT end of the hip shaft (rows 71-72; hand holds the right end), horizontal | left | f24 |
| 2 | `atk/3x atk/3x atk.aseprite`, layer `3x atk`, f4 | 97.9% | (160, 36), ~11 deg down | right | f4 |
| 3 | `dodge atk/dodge atk 1x/dodge atk 1x.aseprite`, layer `dodge atk 1x`, f14 | 97.5% | (94, 22), horizontal | left | f14/f15 alternating (51 px differ, wand identical) |
- `*_raw.png`: the original frame, full native canvas, transparent, character layer only (the screenshots had no fx layer).
- `*_6x.png`: 6x nearest-neighbour copy on dark bg.  `*_beam.gif`: 4x, 40 ms/frame, 43 frames (6 still, 6 charge,
  3 fire, 14 sustain, 6 fade, 8 still), native facing kept, beam fires along the wand.  `*_beam_keyframes.png`: charge/fire/sustain/fade.
Made by `tools/user_picks_beam.py` (beam pipeline from `tools/mera_wand_beam.py`).

Pick 1 was corrected after the user's annotation: the earlier tip (192, 72) was the hand end; the brown/orange diagonals are not the wand.
The beam is drawn in front of her body, so it stays visible where it crosses her coat and front leg.
