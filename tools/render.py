import re,os,glob
from PIL import Image,ImageDraw,ImageFont
OUT='/workspace/assets_survey/previews'; BG=(48,48,52,255); S=3
try: FONT=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf',14)
except: FONT=ImageFont.load_default()
def nat(s): return [int(t) if t.isdigit() else t.lower() for t in re.split(r'(\d+)',s)]
def strip(path,fw=None,fh=None):
    im=Image.open(path).convert('RGBA'); w,h=im.size; fh=fh or h; fw=fw or fh
    assert w%fw==0, (path,w,fw)
    return [im.crop((i*fw,0,(i+1)*fw,fh)) for i in range(w//fw)]
def folder(d):
    fs=sorted([f for f in glob.glob(d+'/*.png')],key=lambda f:nat(os.path.basename(f)))
    return [Image.open(f).convert('RGBA') for f in fs]
def render(pack,char,attacks,fps=12,pad=4,fsz=2):
    # attacks: list of (name, [frames]); all frames same canvas size per pack assumed
    W=max(f.size[0] for _,fr in attacks for f in fr); H=max(f.size[1] for _,fr in attacks for f in fr)
    norm=[]
    for n,fr in attacks:
        nf=[]
        for f in fr:
            c=Image.new('RGBA',(W,H),(0,0,0,0)); c.paste(f,((W-f.size[0])//2,H-f.size[1])); nf.append(c)
        norm.append((n,nf))
    # union bbox of opaque pixels across all frames -> consistent crop (keeps baseline)
    bb=None
    for _,fr in norm:
        for f in fr:
            b=f.getchannel('A').point(lambda a:255 if a>8 else 0).getbbox()
            if b: bb=b if bb is None else (min(bb[0],b[0]),min(bb[1],b[1]),max(bb[2],b[2]),max(bb[3],b[3]))
    bb=(max(0,bb[0]-pad),max(0,bb[1]-pad),min(W,bb[2]+pad),min(H,bb[3]+pad))
    cw,ch=bb[2]-bb[0],bb[3]-bb[1]; LH=22
    def comp(f,label):
        base=Image.new('RGBA',(cw*S,ch*S+LH),BG)
        g=f.crop(bb).resize((cw*S,ch*S),Image.NEAREST); base.alpha_composite(g,(0,LH))
        d=ImageDraw.Draw(base); d.text((6,3),label,fill=(235,235,235),font=FONT)
        return base
    gif=[]
    for n,fr in norm:
        for i,f in enumerate(fr): gif.append(comp(f,f'{char} - {n} ({i+1}/{len(fr)})').convert('RGB'))
    slug=pack.lower().replace(' ','_')
    gp=f'{OUT}/{slug}_{char}_attacks.gif'
    gif[0].save(gp,save_all=True,append_images=gif[1:],duration=int(1000/fps),loop=0,optimize=True)
    # contact sheet
    LW=230; maxn=max(len(fr) for _,fr in norm)
    sheet=Image.new('RGBA',(LW+maxn*cw*fsz+ (maxn+1)*4, len(norm)*(ch*fsz+8)+30),(30,30,34,255))
    d=ImageDraw.Draw(sheet); d.text((6,6),f'{pack} - {char} (x{fsz}, frames in order)',fill=(255,255,255),font=FONT)
    for r,(n,fr) in enumerate(norm):
        y=30+r*(ch*fsz+8); d.text((6,y+ch*fsz//2-8),f'{n} [{len(fr)}f]',fill=(235,235,235),font=FONT)
        for i,f in enumerate(fr):
            x=LW+i*(cw*fsz+4); cell=Image.new('RGBA',(cw*fsz,ch*fsz),BG)
            cell.alpha_composite(f.crop(bb).resize((cw*fsz,ch*fsz),Image.NEAREST)); sheet.alpha_composite(cell,(x,y))
            d.text((x+3,y+2),str(i+1),fill=(150,150,150),font=FONT)
    sp=f'{OUT}/{slug}_{char}_attack_sheet.png'; sheet.save(sp)
    print(gp,os.path.getsize(gp)//1024,'KB |',sp,sheet.size,'| crop',bb,'|',[(n,len(fr)) for n,fr in norm])
    for n,fr in norm:
        bots=[];
        for f in fr:
            b=f.getchannel('A').point(lambda a:255 if a>8 else 0).getbbox(); bots.append(b[3] if b else None)
        print('   baseline(bottom px)',n,bots)
    return gp,sp
A='/workspace/assets_survey'
# 1 CraftPix Kitsune
k=f'{A}/craftpix/free-yokai-pixel-art-character-sprites/Kitsune'
k=f'{A}/craftpix/free-yokai-pixel-art-character-sprites/Karasu_tengu'
render('CraftPix','Karasu_tengu',[(n,strip(f'{k}/{n}.png',128,128)) for n in ['Attack_1','Attack_2','Attack_3']])
# 2 willYEE char_04
w=f'{A}/willyee/LootStrike/LootStrike_Assets/characters/char_04'
render('willYEE','char_04',[(n,strip(f'{w}/{n}.png',144,112)) for n in ['attack1','attack2','attack3']])
# 3 LuizMelo Martial Hero 3
m=f'{A}/luizmelo/Martial Hero 3/Martial Hero 3/Sprite'
render('LuizMelo','Martial_Hero_3',[(n,strip(f'{m}/{n}.png',126,126)) for n in ['Attack1','Attack2','Attack3']])
# 4 chierit Fire Knight
c=f'{A}/chierit/Elementals_fire_knight_FREE_v1.1/Elementals_fire_knight_FREE_v1.1/png/fire_knight'
render('chierit','Fire_Knight',fsz=1,attacks=[(n,folder(f'{c}/{d}')) for n,d in [('1_atk','05_1_atk'),('2_atk','06_2_atk'),('3_atk','07_3_atk'),('sp_atk','08_sp_atk'),('air_atk','air_atk')]])
# 5 ansimuz Terrible Knight
t=f'{A}/ansimuz/Legacy Collection/Legacy Collection/Assets/Gothicvania/Characters/Terrible Knight/Sprites'
render('ansimuz','Terrible_Knight',[(n,folder(f'{t}/{n}')) for n in ['SwordSlash','AttackSide','AttackUp','CrouchSwordSlash','AttackCrouch','JumpAttack','AirSwordSlash']])
