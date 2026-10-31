import sys,json,math; sys.path.insert(0,''+__import__('os').path.abspath(__import__('os').path.join(__import__('os').path.dirname(__file__),'..'))+'/tools')
from ase_render import load,frame
from PIL import Image,ImageDraw,ImageFont
import numpy as np
from scipy import ndimage
P=''+__import__('os').path.abspath(__import__('os').path.join(__import__('os').path.dirname(__file__),'..'))+'/assets/characters/merakintsugi/platformer-character-pack/'
OUT=''+__import__('os').path.abspath(__import__('os').path.join(__import__('os').path.dirname(__file__),'..'))+'/previews/beam/forward_wand'
WAND={(0x2f,0x18,0x50),(0x59,0x45,0x4d),(0xa6,0x4b,0x0a)}; MARK={(0x59,0x45,0x4d),(0xa6,0x4b,0x0a)}
FONT=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf',15)
C=[ # rank, file, layer, frame, note
 (1,'dodge atk/dodge atk 2x/dodge atk 2x.aseprite','dodge atk 2x',0,'arm straight out at chest height, wand forward, near horizontal'),
 (2,'atk/2x-2 atk/2x-2 atk.aseprite','2x-2 atk',9,'deep lunge, both arms forward, wand angled down-forward'),
 (3,'dodge atk/dodge atk 1x/dodge atk 1x.aseprite','dodge atk 1x',13,'wand horizontal at eye level, hand by her face (aiming along it)'),
 (4,'atk/2x atk/2x atk.aseprite','2x atk',3,'arm fully thrust forward, horizontal, but a motion-smear frame'),
 (5,'atk/2x-2 atk/2x-2 atk.aseprite','2x-2 atk',7,'lunge, wand forward-down with smear streaks'),
 (6,'dodge atk/dodge atk 1x/dodge atk 1x.aseprite','dodge atk 1x',10,'eye-level wand with a swing trail'),
 (7,'atk/2x atk/2x atk.aseprite','2x atk',2,'thrust smear, first frame'),
 (8,'atk/2x atk/2x atk.aseprite','to idle(short delay)',13,'wand forward but held across her body; tip only reaches her fist'),
]
S=6; cache={}; rows=[]; tiles=[]
def same(a,layer,i,j): return (np.array(frame(a,i,only={layer}))!=np.array(frame(a,j,only={layer}))).any(-1).sum()
for rank,f,layer,fi,note in C:
    a=cache.setdefault(f,load(P+f)); im=frame(a,fi,only={layer}); A=np.array(im); al=A[...,3]>0
    w=np.zeros(al.shape,bool)
    for y,x in zip(*np.nonzero(al)):
        if tuple(A[y,x,:3]) in WAND: w[y,x]=True
    lab,n=ndimage.label(w,structure=np.ones((3,3))); best=None
    for k in range(1,n+1):
        ys,xs=np.nonzero(lab==k)
        if not any(tuple(A[y,x,:3]) in MARK for y,x in zip(ys,xs)) or len(xs)<5: continue
        key=(-xs.min()) if rank==7 else len(xs)
        if best is None or key>best[2]: best=(xs,ys,key)
    xs,ys,_=best; i=np.argmin(xs); tip=(int(xs[i]),int(ys[i]))           # forward end (she faces left natively)
    pts=np.stack([xs,ys],1).astype(float); c=pts.mean(0); _,_,vt=np.linalg.svd(pts-c); d=vt[0]
    if d[0]>0: d=-d                                                         # point forward (-x)
    ang=math.degrees(math.atan2(-d[1],-d[0]))                               # + = tip up, - = tip down
    # holdable: count identical neighbouring frames
    nf=len(a['frames']); hold={j:int(same(a,layer,fi,j)) for j in range(max(0,fi-2),min(nf,fi+3)) if j!=fi}
    # render flipped (face right) at 6x
    fl=im.transpose(Image.FLIP_LEFT_RIGHT); W0=im.width; tipf=(W0-1-tip[0],tip[1]); df=(-d[0],d[1])
    b=fl.getbbox(); pad=12; box=(b[0]-pad,b[1]-pad,b[2]+pad,b[3]+pad)
    box=(box[0]-max(0,(96-(box[2]-box[0]))//2),box[1],box[2]+max(0,(96-(box[2]-box[0]))-(96-(box[2]-box[0]))//2),box[3]); cw,chh=(box[2]-box[0])*S,(box[3]-box[1])*S; LB=44
    t=Image.new('RGBA',(cw,chh+LB),(16,15,24,255)); spr=Image.new('RGBA',(box[2]-box[0],box[3]-box[1]),(0,0,0,0)); spr.alpha_composite(fl,(-box[0],-box[1]))
    t.alpha_composite(spr.resize((cw,chh),Image.NEAREST),(0,LB))
    dr=ImageDraw.Draw(t)
    # tick: starts 2 px (1x) beyond the tip along the wand, 4 px long, drawn only outside the sprite
    cx0=(tipf[0]-box[0]+0.5)*S; cy0=(tipf[1]-box[1]+0.5)*S+LB
    fa=np.array(fl)[...,3]; st=1.0
    while st<40:
        qx,qy=int(round(tipf[0]+df[0]*st)),int(round(tipf[1]+df[1]*st))
        if not (0<=qx<fa.shape[1] and 0<=qy<fa.shape[0]) or fa[qy,qx]==0: break
        st+=1
    st+=1.5
    def clear(st):
        for u in np.linspace(0,1,15):
            qx,qy=int(round(tipf[0]+df[0]*(st+3.5*u))),int(round(tipf[1]+df[1]*(st+3.5*u)))
            if 0<=qx<fa.shape[1] and 0<=qy<fa.shape[0] and fa[qy,qx]>0: return False
        return True
    while not clear(st) and st<60: st+=1
    p1=(cx0+df[0]*st*S,cy0+df[1]*st*S); p2=(cx0+df[0]*(st+3.5)*S,cy0+df[1]*(st+3.5)*S)
    dr.line([p1,p2],fill=(255,60,60,255),width=4); dr.ellipse([p2[0]-4,p2[1]-4,p2[0]+4,p2[1]+4],fill=(255,60,60,255))
    lab_=f"#{rank} {f.split('/')[-1][:-9]} / {layer} / frame {fi} (1-based {fi+1})"
    dr.text((6,3),lab_,font=FONT,fill=(240,240,240)); dr.text((6,22),f"wand {ang:+.0f} deg (+ up, - down), tip ({tip[0]},{tip[1]}) native",font=FONT,fill=(255,140,140))
    fn=f"{rank:02d}_{f.split('/')[-1][:-9].replace(' ','_')}_{layer.replace(' ','_').replace('(','').replace(')','')}_f{fi}.png"
    t.convert('RGB').save(f'{OUT}/{fn}'); tiles.append(t)
    # verify tick pixels don't overlap sprite
    big=spr.resize((cw,chh),Image.NEAREST); ba=np.array(big)[...,3]
    ov=False
    for u in np.linspace(0,1,20):
        xx=int(p1[0]+(p2[0]-p1[0])*u); yy=int(p1[1]+(p2[1]-p1[1])*u-LB)
        if 0<=yy<chh and 0<=xx<cw and ba[yy,xx]>0: ov=True
    rows.append(dict(rank=rank,file=f,layer=layer,frame=fi,angle_deg=round(ang),tip_native=tip,identical_frames=hold,note=note,png=fn,tick_overlap=bool(ov)))
    print(rank,layer,fi,round(ang),tip,'identical',hold,'overlap',ov,fn)
json.dump(rows,open(f'{OUT}/candidates.json','w'),indent=1,default=int)
# contact sheet, 3 per row
cols=3; cwm=max(t.width for t in tiles); chm=max(t.height for t in tiles); R=(len(tiles)+cols-1)//cols
sh=Image.new('RGB',(cols*(cwm+8),R*(chm+8)),(6,6,10))
for k,t in enumerate(tiles): sh.paste(t.convert('RGB'),((k%cols)*(cwm+8),(k//cols)*(chm+8)))
sh.save(f'{OUT}/forward_wand_contact_sheet.png'); print(sh.size)
