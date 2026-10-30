import sys; sys.path.insert(0,'/workspace/assets_survey')
exec(open('/workspace/assets_survey/compat.py').read())
def seq_frames(fr,durs=None):
    durs=durs or [1]*len(fr); out=[]
    for f,d in zip(fr,durs): out+= [f]*d
    return out
def idle_fill(idle,durs,n,start=0):
    s=seq_frames(idle,durs); return [s[(start+i)%len(s)] for i in range(n)]
def build(seq,idle,idurs,T):
    out=[]
    for kind,val in seq:
        out+= idle_fill(idle,idurs,val,len(out)) if kind=='idle' else val
    return (out+idle_fill(idle,idurs,T,len(out)))[:T]
T=72; SC=3
OG=CH['Ogre']; BGc=CH['Brawler Girl (recolor)']
og_idle=folder(OG[1]); og_atk=folder(OG[2])
bg_idle=folder(BGc[1]); kick=folder(BGc[2]); jab=folder(f'{BG_}/Jab'); punch=folder(f'{BG_}/Punch')
ogre=build([('idle',10),('a',seq_frames(og_atk,[5,1,1,5,1,1,1])),('idle',20),('a',seq_frames(og_atk,[5,1,1,5,1,1,1]))],og_idle,[3,2,3,2],T)
brawl=build([('idle',16),('a',seq_frames(kick,[3,1,1,1,5])),('idle',8),('a',seq_frames(jab,[1,1,3])),('a',seq_frames(punch,[1,1,3])),('idle',8),('a',seq_frames(kick,[3,1,1,1,5]))],bg_idle,[2,2,2,2],T)
def scene(hero,hidle_dir,atks,path):
    hidle=folder(hidle_dir); hanc=anchor(hidle)
    seq=[('idle',6),('a',seq_frames(folder(atks[0]))),('a',seq_frames(folder(atks[1]))),('idle',6),('a',seq_frames(folder(atks[2])))]
    h=build(seq,hidle,None,T)
    base=cemetery(384); frames=[]
    font=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf',14)
    for t in range(T):
        c=base.copy()
        place(c,ogre[t],anchor(og_idle),228)
        place(c,brawl[t],anchor(bg_idle),302,flip=True)
        place(c,h[t],hanc,104)
        big=c.resize((384*SC,224*SC),Image.NEAREST); d=ImageDraw.Draw(big)
        d.text((10,8),f'chierit {hero} vs ansimuz Ogre + Brawler Girl (recolor) | native 1:1, x{SC} | native timings, 100 ms ticks',font=font,fill='white')
        frames.append(big.convert('RGB').quantize(255,dither=Image.NONE))
    frames[0].save(path,save_all=True,append_images=frames[1:],duration=100,loop=0,optimize=False,disposal=1)
    print(path,len(frames))
scene('Water Priestess',f'{WP}/01_idle',[f'{WP}/07_1_atk',f'{WP}/08_2_atk',f'{WP}/09_3_atk'],f'{OUT}/mock_fight_water_priestess_cemetery.gif')
scene('Fire Knight',f'{FK}/01_idle',[f'{FK}/05_1_atk',f'{FK}/06_2_atk',f'{FK}/07_3_atk'],f'{OUT}/mock_fight_fire_knight_cemetery.gif')
