# Lineup of merakintsugi sample heroine vs chierit/ansimuz on the Cemetery bg (native 1:1).
exec(open('/workspace/assets_survey/compat.py').read())
M='/workspace/assets_survey/merakintsugi/sample'; O='/workspace/assets_survey/previews/merakintsugi'
im=Image.open(f'{M}/idle/sprite sheets/idle.png').convert('RGBA')
mk=[im.crop((i*46,0,(i+1)*46,55)) for i in range(10)]
CH['Cemetery Hero']=('ansimuz',f'{A}/ansimuz/extra/gothicvania-cemetery-files/gothicvania-cemetery-files/Assets/Characters/Hero/Sprites/hero-idle',None)
R=[('Fire Knight',None),('Water Priestess',None),('merakintsugi Heroine',mk),('Brawler Girl (recolor)',None),('Cemetery Hero',None),('Ogre',None)]
for scale,fn,title,gap in [(3,'lineup_merakintsugi_vs_chierit_ansimuz_x3_cemetery.png','merakintsugi sample heroine (green) vs chierit (orange) / ansimuz (blue): native 1:1, shown x3',34),(1,'lineup_merakintsugi_raw_1to1.png','raw 1:1',40)]:
  items=[(n,fr or folder(CH[n][1])) for n,fr in R]
  W=sum(fr[0].getbbox()[2]-fr[0].getbbox()[0] for _,fr in items)+gap*(len(items)+1)
  sc=cemetery(W); x=gap; labels=[]
  for n,fr in items:
      f=fr[0];bb=f.getbbox();anc=anchor(fr);cx=x+(anc[0]-bb[0]);place(sc,f,anc,cx);labels.append((n,cx,bb[3]-bb[1]));x+=bb[2]-bb[0]+gap
  big=sc.resize((sc.width*scale,224*scale),Image.NEAREST)
  out=Image.new('RGBA',(big.width,big.height+80),(24,24,28,255));out.paste(big,(0,40));d=ImageDraw.Draw(out)
  fnt=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf',16 if scale>1 else 8)
  d.text((8,10),title,font=fnt,fill='white')
  for n,cx,h in labels:
      col=(140,230,140) if 'merak' in n else ((255,170,90) if CH.get(n,('',))[0]=='chierit' else (120,200,255))
      t=f'{n.replace(" (recolor)","")}\n{h}px';tw=d.multiline_textbbox((0,0),t,font=fnt)[2]
      d.multiline_text((cx*scale-tw//2,40+big.height+4),t,font=fnt,fill=col,align='center')
  out.convert('RGB').save(f'{O}/{fn}'); print(fn,out.size)
sc=cemetery(260)
for (n,fr),x in zip(R[:5],[30,85,135,180,225]):
    fr=fr or folder(CH[n][1]); place(sc,fr[0],anchor(fr),x)
sc.crop((0,125,260,195)).resize((1560,420),Image.NEAREST).convert('RGB').save(f'{O}/style_closeup_merakintsugi_x6.png')
