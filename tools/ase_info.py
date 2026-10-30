import struct,sys,glob,os,zlib
def ase(path):
    d=open(path,'rb').read()
    size,magic,frames,w,h,depth=struct.unpack('<IHHHHH',d[:14])
    assert magic==0xA5E0,path
    off=128; durs=[]; tags=[]; layers=[]; slices=[]
    for i in range(frames):
        fsize,fm,old,dur,_,nnew=struct.unpack('<IHHH2sI',d[off:off+16])
        nch=nnew if nnew else old; durs.append(dur); p=off+16
        for c in range(nch):
            csz,ctype=struct.unpack('<IH',d[p:p+6]); body=d[p+6:p+csz]
            if ctype==0x2004:  # layer
                flags,ltype,child,_,_,blend,opac=struct.unpack('<HHHHHHB',body[:13]); nl=struct.unpack('<H',body[16:18])[0]
                layers.append(body[18:18+nl].decode('utf8','replace'))
            if ctype==0x2018:  # tags
                n=struct.unpack('<H',body[:2])[0]; q=10
                for t in range(n):
                    fr,to,dirn=struct.unpack('<HHB',body[q:q+5]); q+=17
                    nl=struct.unpack('<H',body[q:q+2])[0]; nm=body[q+2:q+2+nl].decode('utf8','replace'); q+=2+nl
                    tags.append((nm,fr,to))
            if ctype==0x2022:
                n=struct.unpack('<I',body[:4])[0]; nl=struct.unpack('<H',body[12:14])[0]; slices.append(body[14:14+nl].decode())
            p+=csz
        off+=fsize
    return dict(frames=frames,w=w,h=h,durs=durs,tags=tags,layers=layers,slices=slices)
if __name__=='__main__':
    for f in sorted(glob.glob('**/*.aseprite',recursive=True)):
        a=ase(f); ds=sorted(set(a['durs']))
        print(f"{f:55s} {a['frames']:3d}f {a['w']}x{a['h']} dur={ds} total={sum(a['durs'])}ms layers={a['layers']} tags={a['tags']} slices={a['slices']}")
