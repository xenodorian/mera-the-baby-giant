import requests,re,sys,os
def dl(g,out):
    s=requests.Session(); s.headers['User-Agent']='Mozilla/5.0'
    r=s.get(g); csrf=re.search(r'name="csrf_token" value="([^"]+)"',r.text).group(1)
    ups=re.findall(r'data-upload_id="(\d+)"',r.text)
    if not ups:
        j=s.post(g+'/download_url',data={'csrf_token':csrf}).json(); p=s.get(j['url']).text; ups=re.findall(r'data-upload_id="(\d+)"',p)
    os.makedirs(out,exist_ok=True)
    for u in dict.fromkeys(ups):
        x=s.post(f'{g}/file/{u}?source=view_game&as_props=1',data={'csrf_token':csrf}).json()
        if 'url' not in x: print('fail',g,u,x); continue
        f=s.get(x['url']); fn=re.search(r'filename="?([^";]+)',f.headers.get('content-disposition','')) 
        fn=fn.group(1) if fn else f'{u}.bin'; open(os.path.join(out,fn),'wb').write(f.content); print(g.split('/')[-1],fn,len(f.content))
for a in sys.argv[2:]: dl(a,sys.argv[1])
