"""Export Mera (merakintsugi hero) animations from .aseprite into Godot-ready horizontal strips.
All strips share ONE cell size and ONE foot pivot, so an AnimatedSprite2D with offset=-pivot never jitters.
Usage: python3 tools/export_mera_frames.py   (run from the repo root)"""
import os,sys,json
sys.path.insert(0,os.path.dirname(__file__))
from ase_render import load,frame
from PIL import Image,ImageDraw
import numpy as np
SRC='assets/characters/merakintsugi/platformer-character-pack'
OUT='assets/characters/merakintsugi/mera_export'
ANIMS={  # name: (file, char layers)
 'idle':('idle/idle.aseprite',['idle']),
 'run_start':('run/run_start.aseprite',['sprint_start']),
 'run':('run/run.aseprite',['sprint']),
 'run_stop':('run/run_stop.aseprite',['sprint stop']),
 'run_turn':('run/run_turn.aseprite',['sprint_turn']),
}
CHAIN=[('run_start','idle',0),('run','run_start',-1),('run_stop','run',-1),('run_turn','run',-1)]
D={k:load(f'{SRC}/{f}') for k,(f,_) in ANIMS.items()}
def img(k,i): return frame(D[k],i)                       # author-visible layers
def mask(im): return np.array(im.getchannel('A'))>0
def bottom(im): return int(np.nonzero(mask(im))[0].max())
def align_x(mref,mnew,dy):
    Hr,Wr=mref.shape; Hn,Wn=mnew.shape; H=Hr+Hn; W=Wr+Wn
    F=np.fft.rfft2(mref.astype(float),(H,W)); G=np.fft.rfft2(mnew[::-1,::-1].astype(float),(H,W))
    corr=np.rint(np.fft.irfft2(F*G,(H,W))); iou=corr/(mref.sum()+mnew.sum()-corr)
    y=dy+Hn-1; x=int(np.argmax(iou[y])); return x-(Wn-1),float(iou[y,x])
off={'idle':(0,0)}; ground=bottom(img('idle',0))
for k,ref,rf in CHAIN:
    rf=rf if rf>=0 else len(D[ref]['frames'])+rf
    dy=ground-bottom(img(k,0))                           # every run anim is grounded: pin feet
    dx,iou=align_x(mask(img(ref,rf)),mask(img(k,0)),dy-off[ref][1])
    off[k]=(off[ref][0]+dx,dy); print(f'{k:10s} offset {off[k]} (matched {ref} f{rf}, IoU {iou:.2f})')
ib=img('idle',0).getbbox(); px=(ib[0]+ib[2])//2           # pivot x = idle body centre, pivot y = below feet row
py=ground+1
L=R=T=B=0
for k in ANIMS:
    for i in range(len(D[k]['frames'])):
        b=img(k,i).getbbox()
        if not b: continue
        L=max(L,px-(b[0]+off[k][0])); R=max(R,b[2]+off[k][0]-px); T=max(T,py-(b[1]+off[k][1])); B=max(B,b[3]+off[k][1]-py)
half=max(L,R)+1; W=2*half; H=T+B+1; pivot=(half,T)                # symmetric around pivot -> flip by scale.x=-1
os.makedirs(OUT,exist_ok=True); meta={'cell':[W,H],'pivot':list(pivot),'faces':'left','source':SRC,'animations':{}}
for k in ANIMS:
    n=len(D[k]['frames']); strip=Image.new('RGBA',(W*n,H),(0,0,0,0)); durs=[]
    for i in range(n):
        f=img(k,i)
        cell=Image.new('RGBA',(W,H),(0,0,0,0)); cell.alpha_composite(f,(half-px+off[k][0],T-py+off[k][1]))
        strip.alpha_composite(cell,(i*W,0)); durs.append(D[k]['frames'][i]['dur'])
    fn=f'mera_{k}_strip{n}.png'; strip.save(f'{OUT}/{fn}')
    meta['animations'][k]={'file':fn,'frames':n,'durations_ms':durs,'loop':k in ('idle','run')}
    print(fn,strip.size,'durations',sorted(set(durs)))
# body height & default hurtbox from idle frame 0 (in cell coords relative to pivot)
c0=Image.open(f"{OUT}/mera_idle_strip10.png").crop((0,0,W,H)); b=c0.getbbox()
meta['idle_body_bbox_rel_pivot']=[b[0]-pivot[0],b[1]-pivot[1],b[2]-pivot[0],b[3]-pivot[1]]
meta['body_height_px']=b[3]-b[1]
json.dump(meta,open(f'{OUT}/mera_frames.json','w'),indent=1); print('cell',W,H,'pivot',pivot,'body h',b[3]-b[1],'bbox rel',meta['idle_body_bbox_rel_pivot'])
# verification sheet (x3): every frame, red pivot cross, blue ground line
rows=list(ANIMS); maxn=max(len(D[k]['frames']) for k in rows); S=3
sh=Image.new('RGBA',(maxn*(W*S+4)+4,len(rows)*(H*S+4)+4),(30,30,34,255)); d=ImageDraw.Draw(sh)
for r,k in enumerate(rows):
    st=Image.open(f"{OUT}/{meta['animations'][k]['file']}")
    for i in range(meta['animations'][k]['frames']):
        x=4+i*(W*S+4); y=4+r*(H*S+4); cell=Image.new('RGBA',(W,H),(48,48,52,255)); cell.alpha_composite(st.crop((i*W,0,(i+1)*W,H)))
        sh.alpha_composite(cell.resize((W*S,H*S),Image.NEAREST),(x,y))
        d.line([(x,y+pivot[1]*S),(x+W*S,y+pivot[1]*S)],fill=(80,140,255,255)); d.line([(x+pivot[0]*S,y),(x+pivot[0]*S,y+H*S)],fill=(255,70,70,160))
sh.save('previews/merakintsugi/mera_export_check_x3.png'); print('check sheet',sh.size)
