"""Hero-anchored compatibility: merakintsugi hero front & centre, chierit alt forms, ansimuz enemy/side char, Cemetery bg, 384x216 viewport."""
import sys,colorsys; sys.argv=['x']
exec(open('/workspace/assets_survey/compat.py').read())      # cemetery(), place(), anchor(), CH, folder (compat_lib)
CHC=CH; folderC=folder
src=open('/workspace/assets_survey/mk_full.py').read(); exec(src[:src.index('# ---------- audit')])   # D, A, off, char(), full()
O='/workspace/assets_survey/previews/merakintsugi/full'
F16=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf',16); F12=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf',12)
def wsv(frames):
    from collections import Counter
    c=Counter()
    for f in frames: c.update(p[:3] for p in f.getdata() if p[3]>0)
    n=sum(c.values()); S=V=0
    for col,k in c.items(): h=colorsys.rgb_to_hsv(*(v/255 for v in col)); S+=h[1]*k; V+=h[2]*k
    return S/n,V/n
def palette_map(frames,blend=0.6,outline=None):
    """palette-level HSV harmonisation toward hero S/V; keeps colour count; optional near-black outline recolour"""
    mS,mV=wsv(frames); cols=set()
    for f in frames: cols|={p[:3] for p in f.getdata() if p[3]>0}
    hsv={c:colorsys.rgb_to_hsv(*(v/255 for v in c)) for c in cols}
    fs=1+blend*(HERO_S/mS-1); fv=1+blend*(HERO_V/mV-1); m={}
    for c,(h,s,v) in hsv.items():
        if outline and (0.299*c[0]+0.587*c[1]+0.114*c[2])<18: m[c]=outline; continue
        r,g,b=colorsys.hsv_to_rgb(h,min(1,s*fs),min(1,v*fv)); m[c]=(round(r*255),round(g*255),round(b*255))
    return m,(fs,fv)
def apply(f,m):
    o=f.copy(); px=o.load()
    for y in range(o.height):
        for x in range(o.width):
            p=px[x,y]
            if p[3]>0: q=m[p[:3]]; px[x,y]=(q[0],q[1],q[2],p[3])
    return o
def viewport(): 
    bg=cemetery(384); return bg.crop((0,8,384,224))   # 384x216 game view; feet line FEET-8
FEET_V=FEET-8
hero_idle=[char('idle',i) for i in range(10)]; hanc=anchor(hero_idle)
HERO_S,HERO_V=wsv(hero_idle); print('hero weighted S %.2f V %.2f'%(HERO_S,HERO_V))
cast=[('Fire Knight','alt form (chierit)',72,False),('Water Priestess','alt form (chierit)',128,False),
      ('Brawler Girl (recolor)','side character (ansimuz)',258,True),('Ogre','enemy (ansimuz)',322,True)]
maps={}
for n,_,_,_ in cast:
    fr=folderC(CHC[n][1]); maps[n]=palette_map(fr,outline=(0x15,0x10,0x37) if n=='Ogre' else None)
    print(n,'weighted S/V %.2f/%.2f'%wsv(fr),'-> S x%.2f V x%.2f'%maps[n][1])
def lineup(tweak,path,title):
    sc=viewport(); labels=[]
    for n,role,x,flip in cast:
        fr=folderC(CHC[n][1]); f=fr[0]; f=apply(f,maps[n][0]) if tweak else f
        place(sc,f,anchor(fr),x,feet=FEET_V,flip=flip); labels.append((n.replace(' (recolor)',''),role,x,f.getbbox()[3]-f.getbbox()[1]))
    place(sc,hero_idle[0],hanc,192,feet=FEET_V+3,flip=True)   # front & centre, mirrored to face the enemies (native = left-facing)
    labels.append(('merakintsugi hero','MAIN CHARACTER',192,55))
    S=4; big=sc.resize((384*S,216*S),Image.NEAREST)
    out=Image.new('RGBA',(big.width,big.height+44+46),(24,24,28,255)); out.paste(big,(0,44)); d=ImageDraw.Draw(out)
    d.text((10,12),title,font=F16,fill='white')
    for n,role,x,h in labels:
        col=(140,230,140) if 'hero' in n else ((255,170,90) if 'chierit' in role else (120,200,255))
        t=f'{n} ({h}px)\n{role}'; tw=d.multiline_textbbox((0,0),t,font=F12)[2]
        d.multiline_text((x*S-tw//2,44+big.height+6),t,font=F12,fill=col,align='center')
    out.convert('RGB').save(path); print(path,out.size)
lineup(False,f'{O}/hero_lineup_cemetery_viewport_x4_raw.png','Hero-anchored lineup, 384x216 game view on Cemetery, native 1:1 shown x4 - RAW (no tweaks)')
lineup(True,f'{O}/hero_lineup_cemetery_viewport_x4_harmonized.png','Same, with palette harmonisation toward the hero (S/V matched 60%, Ogre black outline -> hero navy #151037)')
# x6 close-up: hero next to alt forms raw vs harmonised
sc=viewport()
for (n,x,tw) in [('Fire Knight',38,False),('Fire Knight',95,True),('Water Priestess',145,False),('Water Priestess',175,True),('Ogre',330,False),('Ogre',268,True)]:
    fr=folderC(CHC[n][1]); f=apply(fr[0],maps[n][0]) if tw else fr[0]; place(sc,f,anchor(fr),x,feet=FEET_V)
place(sc,hero_idle[0],hanc,215,feet=FEET_V)
c=sc.crop((0,FEET_V-66,384,FEET_V+6)).resize((384*4,72*4),Image.NEAREST)
o=Image.new('RGBA',(c.width,c.height+30),(24,24,28,255)); o.paste(c,(0,30)); ImageDraw.Draw(o).text((8,6),'x4 close-up: Fire Knight raw | harmonised, Water Priestess raw | harmonised, HERO, Ogre harmonised | raw',font=F16,fill='white')
o.convert('RGB').save(f'{O}/hero_vs_altforms_closeup_x4.png'); print('closeup',o.size)
# ---- mock fight: hero 3-hit combo vs harmonised Ogre + Brawler Girl, 20 ms ticks, native timings ----
TICK=20; T=0
def expand(frames_durs):
    out=[]
    for f,d in frames_durs: out+=[f]*max(1,round(d/TICK))
    return out
hero_seq=[(('idle',i%10),60) for i in range(10)]+[((k,i),D[k]['frames'][i]['dur']) for k,r in [('1x atk',range(10)),('2x atk',range(10)),('3x atk',range(34))] for i in r]+[(('idle',i%10),60) for i in range(10)]
H=expand(hero_seq); T=len(H)
def loop(frames,durs,n,start=0):
    seq=expand(list(zip(frames,durs))); return [seq[(start+i)%len(seq)] for i in range(n)]
og_i=[apply(f,maps['Ogre'][0]) for f in folderC(CHC['Ogre'][1])]; og_a=[apply(f,maps['Ogre'][0]) for f in folderC(CHC['Ogre'][2])]
oa=expand(list(zip(og_a,[500,100,100,500,100,100,100])))
OG=loop(og_i,[300,200,300,200],40)+oa; OG=(OG+loop(og_i,[300,200,300,200],T))[:T]
bg_i=[apply(f,maps['Brawler Girl (recolor)'][0]) for f in folderC(CHC['Brawler Girl (recolor)'][1])]
bg_k=[apply(f,maps['Brawler Girl (recolor)'][0]) for f in folderC(CHC['Brawler Girl (recolor)'][2])]
BGs=loop(bg_i,[200]*4,90)+expand(list(zip(bg_k,[300,100,100,100,500]))); BGs=(BGs+loop(bg_i,[200]*4,T))[:T]
oanc=anchor(og_i); banc=anchor(bg_i); base=viewport(); frames=[]
for t in range(T):
    c=base.copy()
    place(c,OG[t],oanc,262,feet=FEET_V)
    place(c,BGs[t],banc,330,feet=FEET_V,flip=True)
    k,i=H[t]; fr=full(k,i); a=(hanc[0]-off[k][0],hanc[1]-off[k][1])
    place(c,fr,a,170,feet=FEET_V,flip=True)
    big=c.resize((384*3,216*3),Image.NEAREST); ImageDraw.Draw(big).text((8,6),f'HERO (merakintsugi) 3-hit combo vs Ogre + Brawler Girl (harmonised) | 1:1 x3 | native timings | {k}',font=F12,fill='white')
    frames.append(big.convert('RGB').quantize(255,dither=Image.NONE))
p=f'{O}/hero_mock_fight_3hit_vs_ogre_cemetery.gif'
frames[0].save(p,save_all=True,append_images=frames[1:],duration=TICK,loop=0)
print(p,T,'ticks',T*TICK,'ms')
