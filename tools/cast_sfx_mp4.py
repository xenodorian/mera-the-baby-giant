"""Render a cast GIF to MP4 (H.264 + AAC, yuv420p) with sound effects synced to its timeline (user request
[pt40u]: melee SFX on the claw-hand swipe after the rear fireball, pick1 v4).
Video: the GIF's exact frames and durations (already 4x nearest-neighbour), resampled to 100 fps CFR by frame duplication
(every duration is a multiple of 10 ms), played LOOPS times. Audio: Kenney CC0 sounds placed on timeline events.
Usage (repo root): python3 tools/cast_sfx_mp4.py"""
import os, json, subprocess, tempfile
import numpy as np
from PIL import Image, ImageSequence
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
CS = f'{ROOT}/previews/beam/cast_sequences'; SFX = f'{ROOT}/assets/sfx/kenney'; SR = 48000; LOOPS = 2

def dec(p):
    r = subprocess.run(['ffmpeg', '-v', 'error', '-i', p, '-f', 'f32le', '-ac', '1', '-ar', str(SR), '-'], capture_output=True, check=True).stdout
    return np.frombuffer(r, np.float32).copy()
def onset(a, frac=0.1): return int(np.argmax(np.abs(a) > frac * np.abs(a).max()))

def build(name, cues):
    gif = f'{CS}/{name}_cast.gif'; log = json.load(open(f'{CS}/{name}_timeline.json'))
    frames = [f.convert('RGB') for f in ImageSequence.Iterator(Image.open(gif))]
    durs = [L['ms'] for L in log]; T = sum(durs)
    def t_of(anim, frame, phase=None):
        return next(L['t'] for L in log if L['anim'] == anim and L['frame'] == frame and (phase is None or L['phase'] == phase))
    # ---- audio: each cue = (file, event time ms, align 'onset'|'peak', gain dB)
    mix = np.zeros(int(SR * T * LOOPS / 1000) + SR, np.float32); placed = []
    for cue in cues(t_of, log):
        f, tev, align, db = cue[:4]; trim = cue[4] if len(cue) > 4 else None
        a = dec(f'{SFX}/{f}'); a = a / np.abs(a).max()
        if trim:   # keep the first `trim` ms, 50 ms linear fade-out
            n = int(trim / 1000 * SR); a = a[:n].copy(); fl = int(0.05 * SR); a[-fl:] *= np.linspace(1, 0, fl)
        k = onset(a) if align == 'onset' else int(np.argmax(np.abs(a)))
        for lp in range(LOOPS):
            st = int((tev + lp * T) / 1000 * SR) - k
            seg = a[max(0, -st):] * 10 ** (db / 20); st = max(st, 0); n = min(len(seg), len(mix) - st); mix[st:st + n] += seg[:n]
        placed.append(dict(file=f, event_ms=tev, align=align, gain_db=db, trim_ms=trim, file_start_ms=round(tev - k / SR * 1000, 1), audible_from_ms=round(tev - k / SR * 1000 + onset(a) / SR * 1000, 1)))
    mix = mix[:int(SR * T * LOOPS / 1000)]
    pk = np.abs(mix).max(); mix *= 0.89 / pk                      # normalise to -1 dBFS peak, no clipping
    with tempfile.TemporaryDirectory() as td:
        mix.astype('<f4').tofile(f'{td}/a.f32')
        lst = []
        for lp in range(LOOPS):
            for i, (fr, d) in enumerate(zip(frames, durs)):
                p = f'{td}/f{i:03d}.png'
                if lp == 0: fr.save(p)
                lst.append(f"file '{p}'\nduration {d / 1000:.3f}")
        lst.append(f"file '{td}/f{len(frames) - 1:03d}.png'")
        open(f'{td}/list.txt', 'w').write('\n'.join(lst) + '\n')
        out = f'{CS}/{name}_sfx.mp4'
        subprocess.run(['ffmpeg', '-v', 'error', '-y', '-f', 'concat', '-safe', '0', '-i', f'{td}/list.txt',
                        '-f', 'f32le', '-ar', str(SR), '-ac', '1', '-i', f'{td}/a.f32',
                        '-vf', 'fps=100', '-c:v', 'libx264', '-preset', 'slow', '-crf', '14', '-pix_fmt', 'yuv420p', '-tune', 'animation',
                        '-c:a', 'aac', '-b:a', '160k', '-ac', '2', '-t', f'{T * LOOPS / 1000:.3f}', '-movflags', '+faststart', out], check=True)
    meta = dict(mp4=os.path.relpath(out, ROOT), loops=LOOPS, loop_ms=T, cues=placed, normalise_gain_db=round(float(20 * np.log10(0.89 / pk)), 2), bytes=os.path.getsize(out))
    json.dump(meta, open(f'{CS}/{name}_sfx.json', 'w'), indent=1); print(meta)

def pick1_v4_cues(t_of, log):
    t_fire = next(L['t'] for L in log if L['phase'] == 'fire'); t_hit = next(L['t'] for L in log if L['explosion_frame'] == 0)
    return [
        # MELEE (focus): claw-hand swipe after the shot. 3x atk f25 raises the clawed hand, f26 is the first frame of the
        # swipe smear (contact), f27 the follow-through. knifeSlice2's slash transient lands on f26; the file's second
        # 'shing' swell (220-300 ms in) is trimmed off so it doesn't read as a second hit or blur the impact boom.
        ('rpg-audio/knifeSlice2.ogg', t_of('3x atk', 26), 'peak', 0.0, 180),
        # cast extras, kept well under the swipe: magic swell through the charge peaking on the fire frame, low boom on impact
        ('sci-fi-sounds/forceField_000.ogg', t_fire, 'peak', -15.0),
        ('sci-fi-sounds/lowFrequency_explosion_001.ogg', t_hit, 'onset', -9.0),
    ]

if __name__ == '__main__':
    build('pick1_v4_projectile', pick1_v4_cues)
