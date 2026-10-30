"""Render + audit the full merakintsugi Platformer Character Pack straight from the .aseprite sources."""
import sys,os,json; sys.path.insert(0,'/workspace/assets_survey')
from ase_render import load,frame
from PIL import Image,ImageDraw,ImageFont
import numpy as np
X=sys.argv[1] if len(sys.argv)>1 else '/workspace/assets_survey/merakintsugi/full/x'
OUT=sys.argv[2] if len(sys.argv)>2 else '/workspace/assets_survey/previews/merakintsugi/full'
os.makedirs(OUT,exist_ok=True)
FONT=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf',14); BG=(48,48,52,255)
A={ # key: (file, char layers)
 'idle':('idle/idle.aseprite',['idle']),
 '1x atk':('atk/1x atk/1x atk_c.aseprite',['1x atk','to idle']),
 '2x atk':('atk/2x atk/2x atk.aseprite',['2x atk','to idle(short delay)']),
 '2x-1 atk':('atk/2x-1 atk/2x-1 atk.aseprite',['2x-1 atk']),
 '2x-2 atk':('atk/2x-2 atk/2x-2 atk.aseprite',['2x-2 atk']),
 '3x atk':('atk/3x atk/3x atk.aseprite',['3x atk']),
 'dodge atk 1x':('dodge atk/dodge atk 1x/dodge atk 1x.aseprite',['dodge atk 1x','to idle']),
 'dodge atk 2x':('dodge atk/dodge atk 2x/dodge atk 2x.aseprite',['dodge atk 2x']),
 'vertical atk (dodge atk 3x)':('dodge atk/dodge atk 3x(vertical atk)/dodge atk 3x.aseprite',['vertical atk','vertical atk fall loop']),
 'jump atk 1x':('jump attack/jump atk 1x/jump attack 1x.aseprite',['jump atk 1x']),
 'jump atk 2x':('jump attack/jump atk 2x/jump atk 2x.aseprite',['jump atk 2x']),
 'back dodge':('back dodge/back dodge.aseprite',['back dodge']),
 'aerial dash':('aerial dash/aerial dash.aseprite',['aerial dash']),
 'slide':('slide/slide.aseprite',['slide','to','from']),
 'jump':('jump/jump.aseprite',['jump','landing']),
}
D={k:load(f'{X}/{f}') for k,(f,_) in A.items()}
def full(k,i): return frame(D[k],i)
def char(k,i): return frame(D[k],i,only=set(A[k][1]))
def mask(im): return np.array(im.getchannel('A'))>0
def align(mref,mnew,fixdy=None):
    """full-range offset (dx,dy) so new canvas coords + (dx,dy) best overlap ref, via FFT correlation; returns (dx,dy,iou)"""
    Hr,Wr=mref.shape; Hn,Wn=mnew.shape; H=Hr+Hn; W=Wr+Wn
    F=np.fft.rfft2(mref.astype(float),(H,W)); G=np.fft.rfft2(mnew[::-1,::-1].astype(float),(H,W))
    corr=np.rint(np.fft.irfft2(F*G,(H,W)))  # corr[y,x] = overlap when new shifted by (x-(Wn-1), y-(Hn-1))
    rs=mref.sum(); ns=mnew.sum(); iou=corr/(rs+ns-corr)
    if fixdy is None: y,x=np.unravel_index(np.argmax(iou),iou.shape)
    else: y=fixdy+(Hn-1); x=int(np.argmax(iou[y]))
    return int(x-(Wn-1)),int(y-(Hn-1)),float(iou[y,x])
# anchors: offset of each anim canvas in idle-canvas coordinates
off={'idle':(0,0)}; match={}
chain=[('1x atk','idle',0),('2x atk','1x atk',9),('2x-1 atk','2x atk',9),('2x-2 atk','2x-1 atk',5),('3x atk','2x atk',9),
       ('dodge atk 1x','idle',0),('dodge atk 2x','dodge atk 1x',15),('vertical atk (dodge atk 3x)','dodge atk 2x',15),
       ('back dodge','idle',0),('slide','idle',0),('jump','idle',0),('aerial dash','jump',8),('jump atk 1x','jump',8),('jump atk 2x','jump atk 1x',8)]
idle_bottom=int(max(np.nonzero(mask(char('idle',0)))[0]))
def bottom(k,i): return int(max(np.nonzero(mask(char(k,i)))[0]))
GROUND={'1x atk':0,'2x atk':0,'2x-1 atk':0,'2x-2 atk':0,'3x atk':0,'dodge atk 1x':0,'back dodge':0,'slide':0,'jump':0,'vertical atk (dodge atk 3x)':-1}
for k,ref,rf in chain:
    if k in GROUND:
        gi=GROUND[k] if GROUND[k]>=0 else len(D[k]['frames'])-1
        dy_abs=idle_bottom-bottom(k,gi)            # canvas y offset in idle coords
        dx,dy,iou=align(mask(char(ref,rf)),mask(char(k,0)),fixdy=dy_abs-off[ref][1])
    else:
        dx,dy,iou=align(mask(char(ref,rf)),mask(char(k,0)))
    off[k]=(int(off[ref][0]+dx),int(off[ref][1]+dy)); match[k]=(ref,rf,round(float(iou),3))
idle_bottom=max(np.nonzero(mask(char('idle',0)))[0])
# ---------- audit ----------
idle_cols=set()
for i in range(len(D['idle']['frames'])): idle_cols|={p[:3] for p in char('idle',i).getdata() if p[3]>0}
audit={}
for k in A:
    a=D[k]; W,H=a['W'],a['H']; n=len(a['frames']); clip=[]; bots=[]; newc=set(); semi=0
    for i in range(n):
        f=full(k,i); m=np.array(f.getchannel('A'))
        e=[s for s,v in (('top',m[0].any()),('bottom',m[-1].any()),('left',m[:,0].any()),('right',m[:,-1].any())) if v]
        if e: clip.append((i+1,e))
        c=char(k,i); cm=mask(c)
        if cm.any(): bots.append(int(max(np.nonzero(cm)[0]))+off[k][1]-int(idle_bottom))
        else: bots.append(None)
        px=[p for p in c.getdata() if p[3]>0]; newc|={p[:3] for p in px}-idle_cols; semi+=sum(1 for p in px if p[3]<255)
    audit[k]=dict(frames=n,canvas=f'{W}x{H}',durs_ms=sorted(set(fr['dur'] for fr in a['frames'])),total_ms=sum(fr['dur'] for fr in a['frames']),
                  edge_touch=clip,feet_offset_vs_idle=bots,new_char_colours=sorted('#%02x%02x%02x'%c for c in newc),semi_alpha_char_px=semi,
                  chain_match=match.get(k),offset=off[k],tags=a['tags'])
json.dump(audit,open(f'{OUT}/audit.json','w'),indent=1,default=int)
for k,v in audit.items():
    print(f"{k:28s} {v['frames']:3d}f {v['canvas']:8s} {v['durs_ms']} {v['total_ms']}ms chain={v['chain_match']} edge={v['edge_touch'][:6]}{'...' if len(v['edge_touch'])>6 else ''} newcol={len(v['new_char_colours'])} {v['new_char_colours'][:6]} semi={v['semi_alpha_char_px']}")
    print('      feet vs idle:',v['feet_offset_vs_idle'])
# ---------- render ----------
GROUPS={
 '3hit_combo':[('1x atk',range(0,10)),('2x atk',range(0,10)),('3x atk',range(0,34))],
 '5hit_combo_vertical_finisher':[('1x atk',range(0,10)),('2x atk',range(0,10)),('2x-1 atk',range(0,6)),('2x-2 atk',range(0,10)),('vertical atk (dodge atk 3x)',None)],
 'dodge_atk_combo':[('back dodge',range(0,17)),('dodge atk 1x',range(0,16)),('dodge atk 2x',range(0,16)),('vertical atk (dodge atk 3x)',None)],
 'jump_attacks':[('jump',range(0,9)),('jump atk 1x',None),('jump atk 2x',None)],
 'mobility_evasive':[('back dodge',None),('aerial dash',None),('slide',None)],
 'single_attacks_with_recovery':[('1x atk',None),('2x atk',range(0,19)),('2x-1 atk',None),('2x-2 atk',None),('3x atk',None),('dodge atk 1x',None)],
}
def place_all(seq):
    items=[]
    for k,r in seq:
        r=r if r is not None else range(len(D[k]['frames']))
        for j,i in enumerate(r): items.append((k,i,j,len(r)))
    xs=[];ys=[]
    for k,i,_,_ in items:
        b=full(k,i).getbbox()
        if b: xs+= [b[0]+off[k][0],b[2]+off[k][0]]; ys+=[b[1]+off[k][1],b[3]+off[k][1]]
    x0,y0,x1,y1=min(xs)-4,min(ys)-4,max(xs)+4,max(ys)+4
    return items,(x0,y0,x1,y1)
def canvas(k,i,box,scale):
    x0,y0,x1,y1=box; c=Image.new('RGBA',(x1-x0,y1-y0),BG); c.alpha_composite(full(k,i),(off[k][0]-x0,off[k][1]-y0))
    return c.resize((c.width*scale,c.height*scale),Image.NEAREST)
def gif(name,seq,scale=3):
    items,box=place_all(seq); fr=[]; du=[]
    for k,i,j,n in items:
        c=canvas(k,i,box,scale); top=Image.new('RGBA',(c.width,24),(24,24,28,255)); o=Image.new('RGBA',(c.width,c.height+24)); o.paste(top,(0,0)); o.paste(c,(0,24))
        d=ImageDraw.Draw(o); dd=D[k]['frames'][i]['dur']; d.text((6,4),f'{k} ({j+1}/{n}) {dd}ms',font=FONT,fill=(235,235,235))
        gy=24+(idle_bottom+1-box[1])*scale; d.line([(0,gy),(o.width,gy)],fill=(90,90,100,255))
        fr.append(o.convert('RGB')); du.append(dd)
    p=f'{OUT}/merakintsugi_hero_{name}.gif'; fr[0].save(p,save_all=True,append_images=fr[1:],duration=du,loop=0)
    print(p,len(fr),'frames',sum(du),'ms',fr[0].size)
for g,s in GROUPS.items(): gif(g,s)
# full attack sheet: one block per animation, wrap 12 per row, x2, per-anim crop
SHEET=['1x atk','2x atk','2x-1 atk','2x-2 atk','3x atk','dodge atk 1x','dodge atk 2x','vertical atk (dodge atk 3x)','jump atk 1x','jump atk 2x','back dodge','aerial dash','slide']
S=2; COLS=12; blocks=[]
for k in SHEET:
    n=len(D[k]['frames']); bb=None
    for i in range(n):
        b=full(k,i).getbbox()
        if not b: continue
        bb=b if bb is None else (min(bb[0],b[0]),min(bb[1],b[1]),max(bb[2],b[2]),max(bb[3],b[3]))
    bb=(max(0,bb[0]-2),max(0,bb[1]-2),min(D[k]['W'],bb[2]+2),min(D[k]['H'],bb[3]+2)); cw,ch=(bb[2]-bb[0])*S,(bb[3]-bb[1])*S
    rows=(n+COLS-1)//COLS; blk=Image.new('RGBA',(COLS*(cw+4)+4,rows*(ch+4)+26),(30,30,34,255)); d=ImageDraw.Draw(blk)
    a=audit[k]; d.text((6,5),f"{k}  [{n} frames, {'/'.join(map(str,a['durs_ms']))} ms, {a['total_ms']} ms total, canvas {a['canvas']}]",font=FONT,fill='white')
    idx=[i for i in range(n) if full(k,i).getbbox()]
    n=len(idx); rows=(n+COLS-1)//COLS; blk=Image.new('RGBA',(COLS*(cw+4)+4,rows*(ch+4)+26),(30,30,34,255)); d=ImageDraw.Draw(blk)
    d.text((6,5),f"{k}  [{n} frames, {'/'.join(map(str,a['durs_ms']))} ms, canvas {a['canvas']}]",font=FONT,fill='white')
    for j,i in enumerate(idx):
        x=4+(j%COLS)*(cw+4); y=26+(j//COLS)*(ch+4); cell=Image.new('RGBA',(bb[2]-bb[0],bb[3]-bb[1]),BG); cell.alpha_composite(full(k,i).crop(bb))
        blk.alpha_composite(cell.resize((cw,ch),Image.NEAREST),(x,y)); d.text((x+3,y+2),str(i+1),font=FONT,fill=(150,150,150))
    blocks.append(blk)
W=max(b.width for b in blocks); H=sum(b.height+6 for b in blocks)+34
sh=Image.new('RGBA',(W,H),(22,22,26,255)); ImageDraw.Draw(sh).text((6,8),'merakintsugi Platformer Character Pack v1 - all offensive / evasive animations (x2, composited from .aseprite, author layer visibility)',font=FONT,fill='white')
y=34
for b in blocks: sh.alpha_composite(b,(0,y)); y+=b.height+6
sh.convert('RGB').save(f'{OUT}/merakintsugi_hero_full_attack_sheet.png'); print('sheet',sh.size)
