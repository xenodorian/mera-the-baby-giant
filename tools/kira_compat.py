# Kira (Sprite Kitchen) proofs: idle-vs-attack scale mismatch, and lineup vs chierit/ansimuz on Cemetery bg.
exec(open('/workspace/assets_survey/compat.py').read())
K='/workspace/assets_survey/spritekitchen/kira'; O='/workspace/assets_survey/previews/spritekitchen'
def kf(n,c,i=0): return Image.open(f'{K}/spr_kira_{n}_strip{c}.png').convert('RGBA').crop((i*256,0,(i+1)*256,256))
F16=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf',16)
# 1) scale mismatch
pan=[('idle f1 (191 px body)',kf('idle',24)),('walk f1 (133 px)',kf('walk',24)),('sword attack f1 (132 px)',kf('hit',86))]
o=Image.new('RGBA',(3*266+10,300),(24,24,28,255)); d=ImageDraw.Draw(o)
for i,(t,f) in enumerate(pan):
    c=Image.new('RGBA',(256,256),(48,48,52,255)); c.alpha_composite(f); o.alpha_composite(c,(10+i*266,34)); d.text((10+i*266,8),t,font=F16,fill='white')
    b=f.getbbox(); d.rectangle([10+i*266+b[0],34+b[1],10+i*266+b[2]-1,34+b[3]-1],outline=(255,80,80,255))
d.line([(0,34+225),(o.width,34+225)],fill=(255,200,0,255)); d.line([(0,34+201),(o.width,34+201)],fill=(0,200,255,255))
o.convert('RGB').save(f'{O}/kira_idle_vs_attack_scale_mismatch.png'); print('mismatch',o.size)
# 2) lineup
CH['Cemetery Hero']=('ansimuz',f'{A}/ansimuz/extra/gothicvania-cemetery-files/gothicvania-cemetery-files/Assets/Characters/Hero/Sprites/hero-idle',None)
walk=kf('walk',24); wb=walk.getbbox(); body=walk.crop(wb)
third_n=body.resize((round(body.width/3),round(body.height/3)),Image.NEAREST)
third_q=body.resize((round(body.width/3),round(body.height/3)),Image.BOX)
a=third_q.getchannel('A').point(lambda v:255 if v>=128 else 0)
third_q=third_q.convert('RGB').quantize(16,method=Image.MEDIANCUT,dither=Image.NONE).convert('RGBA'); third_q.putalpha(a)
def pad(im): c=Image.new('RGBA',(im.width+2,im.height+2)); c.alpha_composite(im,(1,1)); return [c]
R=[('Fire Knight',None,'chierit'),('Water Priestess',None,'chierit'),('Brawler Girl',folder(CH['Brawler Girl (recolor)'][1]),'ansimuz'),('Cemetery Hero',None,'ansimuz'),('Ogre',None,'ansimuz'),
   ('Kira 1/3 nearest',pad(third_n),'sk'),('Kira 1/3 box+16 colours',pad(third_q),'sk'),('Kira native 1:1 (walk)',pad(body),'sk')]
gap=30; items=[(n,fr or folder(CH[n][1]),p) for n,fr,p in R]
W=sum(fr[0].getbbox()[2]-fr[0].getbbox()[0] for _,fr,_ in items)+gap*(len(items)+1)
sc=cemetery(W); x=gap; labels=[]
for n,fr,p in items:
    f=fr[0];bb=f.getbbox();anc=anchor(fr);cx=x+(anc[0]-bb[0]);place(sc,f,anc,cx);labels.append((n,cx,bb[3]-bb[1]-(2 if p=='sk' else 0),p));x+=bb[2]-bb[0]+gap
for scale,fn in [(3,'lineup_kira_vs_chierit_ansimuz_x3_cemetery.png'),(1,'lineup_kira_raw_1to1.png')]:
    big=sc.resize((W*scale,224*scale),Image.NEAREST)
    out=Image.new('RGBA',(big.width,big.height+80),(24,24,28,255));out.paste(big,(0,40));dd=ImageDraw.Draw(out)
    fnt=F16 if scale>1 else ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf',8)
    dd.text((8,10),'Sprite Kitchen Kira (pink) vs chierit (orange) / ansimuz (blue) on Cemetery, shown x%d'%scale,font=fnt,fill='white')
    for n,cx,h,p in labels:
        col={'chierit':(255,170,90),'ansimuz':(120,200,255),'sk':(255,140,200)}[p]
        t=f'{n}\n{h}px';tw=dd.multiline_textbbox((0,0),t,font=fnt)[2]
        dd.multiline_text((cx*scale-tw//2,40+big.height+4),t,font=fnt,fill=col,align='center')
    out.convert('RGB').save(f'{O}/{fn}'); print(fn,out.size)
# x6 closeup of the downscaled Kira next to chierit/ansimuz
sc2=cemetery(200)
for (n,fr),x in zip([('Fire Knight',None),('Kira',pad(third_q)),('Brawler Girl (recolor)',None),('Kira',pad(third_n))],[35,85,130,170]):
    fr=fr or folder(CH[n][1]); place(sc2,fr[0],anchor(fr),x)
sc2.crop((0,125,200,195)).resize((1200,420),Image.NEAREST).convert('RGB').save(f'{O}/style_closeup_kira_downscaled_x6.png')
