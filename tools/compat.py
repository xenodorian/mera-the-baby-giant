from compat_lib import *
from PIL import ImageDraw, ImageFont
OUT=f'{A}/previews/compat'
CEM=f'{A}/ansimuz/extra/gothicvania-cemetery-files/gothicvania-cemetery-files/Assets/Environment'
FONT=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf',11)
GROUND_TOP=172; FEET=188  # native px in a 224-tall scene
def cemetery(W):
    bg=Image.open(f'{CEM}/background.png').convert('RGBA'); mt=Image.open(f'{CEM}/mountains.png').convert('RGBA')
    gy=Image.open(f'{CEM}/graveyard.png').convert('RGBA'); ts=Image.open(f'{CEM}/tileset.png').convert('RGBA')
    tile=ts.crop((64,48,128,96))
    o=Image.new('RGBA',(W,224),(12,8,24,255))
    for x in range(0,W,bg.width): o.alpha_composite(bg,(x,0))
    for x in range(0,W,mt.width): o.alpha_composite(mt,(x,224-mt.height-30))
    for x in range(0,W,gy.width): o.alpha_composite(gy,(x,224-gy.height-20))
    d=ImageDraw.Draw(o); d.rectangle([0,GROUND_TOP+30,W,224],fill=(23,14,28,255))
    for x in range(0,W,64): o.alpha_composite(tile,(x,GROUND_TOP))
    return o
def anchor(idle):
    b=ubox(idle); return ((b[0]+b[2])//2, b[3])  # feet centre in frame coords
def place(canvas,frame,anc,x,feet=FEET,flip=False):
    ax,ay=anc
    if flip: frame=frame.transpose(Image.FLIP_LEFT_RIGHT); ax=frame.width-ax
    canvas.alpha_composite(frame,(x-ax,feet-ay))
