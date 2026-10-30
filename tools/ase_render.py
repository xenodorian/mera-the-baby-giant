"""Minimal Aseprite (.aseprite) reader/renderer for RGBA files: layers, cels (raw/linked/compressed), tags, durations."""
import struct,zlib
from PIL import Image
def load(path):
    d=open(path,'rb').read()
    _,magic,nframes,W,H,depth=struct.unpack('<IHHHHH',d[:14]); assert magic==0xA5E0 and depth==32
    off=128; layers=[]; frames=[]; tags=[]
    for fi in range(nframes):
        fsize,fm,old,dur,_,nnew=struct.unpack('<IHHH2sI',d[off:off+16]); nch=nnew or old; p=off+16; cels={}
        for _ in range(nch):
            csz,ct=struct.unpack('<IH',d[p:p+6]); b=d[p+6:p+csz]
            if ct==0x2004:
                flags,ltype,child,_,_,blend,opac=struct.unpack('<HHHHHHB',b[:13]); nl=struct.unpack('<H',b[16:18])[0]
                layers.append(dict(name=b[18:18+nl].decode('utf8','replace'),visible=bool(flags&1),type=ltype,child=child,opacity=opac,blend=blend))
            elif ct==0x2005:
                li,x,y,op,ctype=struct.unpack('<HhhBH',b[:9]); r=b[16:]
                if ctype==1: cels[li]=('link',struct.unpack('<H',r[:2])[0],op)
                else:
                    w,h=struct.unpack('<HH',r[:4]); raw=r[4:] if ctype==0 else zlib.decompress(r[4:])
                    cels[li]=('img',(x,y,Image.frombytes('RGBA',(w,h),raw[:w*h*4])),op)
            elif ct==0x2018:
                n=struct.unpack('<H',b[:2])[0]; q=10
                for _ in range(n):
                    fr,to,_d=struct.unpack('<HHB',b[q:q+5]); q+=17; nl=struct.unpack('<H',b[q:q+2])[0]
                    tags.append((b[q+2:q+2+nl].decode('utf8','replace'),fr,to)); q+=2+nl
            p+=csz
        frames.append(dict(dur=dur,cels=cels)); off+=fsize
    # resolve links
    for fi,f in enumerate(frames):
        for li,c in list(f['cels'].items()):
            if c[0]=='link': src=frames[c[1]]['cels'].get(li); f['cels'][li]=src if src else None
    return dict(W=W,H=H,layers=layers,frames=frames,tags=tags,path=path)
def parent_visible(a,li):
    # walk child levels back to find parent groups
    L=a['layers']; lvl=L[li]['child']
    for j in range(li-1,-1,-1):
        if L[j]['child']<lvl:
            if not L[j]['visible']: return False
            lvl=L[j]['child']
            if lvl==0: break
    return True
def frame(a,fi,only=None,use_visibility=True):
    """Composite frame fi. only = set of layer names to include (overrides visibility)."""
    W,H=a['W'],a['H']; out=Image.new('RGBA',(W,H),(0,0,0,0)); f=a['frames'][fi]
    for li,L in enumerate(a['layers']):
        if L['type']!=0: continue
        if only is not None:
            if L['name'] not in only: continue
        elif use_visibility and (not L['visible'] or not parent_visible(a,li)): continue
        c=f['cels'].get(li)
        if not c: continue
        x,y,img=c[1]; op=c[2]*L['opacity']/255/255
        if op<1:
            al=img.getchannel('A').point(lambda v:int(v*op)); img=img.copy(); img.putalpha(al)
        tmp=Image.new('RGBA',(W,H),(0,0,0,0)); tmp.paste(img,(x,y)); out=Image.alpha_composite(out,tmp)
    return out
def layer_frames(a,name):
    li=[i for i,L in enumerate(a['layers']) if L['name']==name]
    return [fi for fi,f in enumerate(a['frames']) if any(f['cels'].get(i) for i in li)]
