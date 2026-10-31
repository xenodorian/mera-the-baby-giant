import sys,glob,json,re; sys.path.insert(0,''+__import__('os').path.abspath(__import__('os').path.join(__import__('os').path.dirname(__file__),'..'))+'/tools')
from ase_render import load,frame
import numpy as np
from scipy import ndimage
P=''+__import__('os').path.abspath(__import__('os').path.join(__import__('os').path.dirname(__file__),'..'))+'/assets/characters/merakintsugi/platformer-character-pack/'
NONCHAR=re.compile(r'fx|illusion|smoke|spark|^0\d$',re.I)
WAND={(0x2f,0x18,0x50),(0x59,0x45,0x4d),(0xa6,0x4b,0x0a)}
EYE={(0x14,0xd2,0x69),(0x08,0x6e,0x35)}
HAIR={(0xb2,0xb2,0xff),(0x9e,0xa0,0xfa)}
res=[]
for p in sorted(glob.glob(P+'**/*.aseprite',recursive=True)):
    a=load(p); rel=p.split('pack/')[1]
    for li,L in enumerate(a['layers']):
        if L['type']!=0 or NONCHAR.search(L['name']): continue
        for fi,f in enumerate(a['frames']):
            if not f['cels'].get(li): continue
            im=np.array(frame(a,fi,only={L['name']}))
            al=im[...,3]>0
            if al.sum()<50: continue
            rgb=[tuple(x) for x in im[...,:3].reshape(-1,3)]
            key=lambda S: np.array([c in S for c in rgb]).reshape(al.shape)&al
            w=key(WAND); eye=key(EYE); hair=key(HAIR)
            ys,xs=np.nonzero(al); cx=xs.mean(); bx0,bx1=xs.min(),xs.max()
            facing=None
            if eye.any() and hair.any():
                facing=-1 if np.nonzero(eye)[1].mean()<np.nonzero(hair)[1].mean() else 1
            lab,n=ndimage.label(w,structure=np.ones((3,3)))
            best=None
            for k in range(1,n+1):
                cy_,cx_=np.nonzero(lab==k)
                if len(cx_)<5: continue
                has=any(tuple(im[y,x,:3]) in {(0x59,0x45,0x4d),(0xa6,0x4b,0x0a)} for y,x in zip(cy_,cx_))
                if not has: continue
                pts=np.stack([cx_,cy_],1).astype(float); c=pts.mean(0); u,s,vt=np.linalg.svd(pts-c); d=vt[0]
                pr=(pts-c)@d; e1=c+d*pr.min(); e2=c+d*pr.max(); ln=pr.max()-pr.min()
                elong=s[0]/(s[1]+1e-6)
                if ln<8 or elong<2.0: continue
                # tip = endpoint farther from body centroid
                bc=np.array([cx,ys.mean()])
                tip,base=(e1,e2) if np.linalg.norm(e1-bc)>np.linalg.norm(e2-bc) else (e2,e1)
                if best is None or ln>best['len']: best=dict(len=round(float(ln),1),tip=[round(float(tip[0])),round(float(tip[1]))],base=[round(float(base[0])),round(float(base[1]))],elong=round(float(elong),1))
            r=dict(file=rel,layer=L['name'],frame=fi,facing=facing,bbox=[int(bx0),int(ys.min()),int(bx1),int(ys.max())],cx=round(float(cx),1))
            if best:
                r.update(best)
                v=np.array(best['tip'])-np.array(best['base'])
                # angle relative to facing: 0 = straight forward horizontal, + = up
                f_=facing or -1
                r['angle_fwd']=round(float(np.degrees(np.arctan2(-v[1],v[0]*f_))),0)
                r['tip_fwd_px']=round(float((best['tip'][0]-cx)*f_),1)   # >0 = tip in front of body centre
            res.append(r)
json.dump(res,open('detect.json','w'),indent=0)
print(len(res),'frames')
c=[r for r in res if r.get('tip_fwd_px',-99)>0]
print(len(c),'candidates (tip in front of body centre)')
for r in c: print(r['file'].split('/')[-1],r['layer'],r['frame'],'face',r['facing'],'len',r['len'],'ang',r['angle_fwd'],'fwd',r['tip_fwd_px'],'tip',r['tip'])
