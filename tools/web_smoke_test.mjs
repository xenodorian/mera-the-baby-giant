// Web build smoke test: serve build/web on :8765 (python -m http.server 8765), then
// node tools/web_smoke_test.mjs out.png  -> loads the game in headless Chrome, presses Up x5 + Right, screenshots, prints console.
import { spawn } from 'node:child_process';
import fs from 'node:fs';
const port = 9333;
const chrome = spawn('google-chrome', ['--headless=new','--no-sandbox','--enable-unsafe-swiftshader','--use-angle=swiftshader',
  '--window-size=1920,1080',`--remote-debugging-port=${port}`,'--user-data-dir=/tmp/cdp-prof','about:blank'], {stdio:'ignore'});
const sleep = ms => new Promise(r => setTimeout(r, ms));
let targets;
for (let i=0;i<50;i++){ try{ targets = await (await fetch(`http://127.0.0.1:${port}/json`)).json(); if (targets.find(t=>t.type==='page')) break;}catch{} await sleep(200); }
const page = targets.find(t=>t.type==='page');
const ws = new WebSocket(page.webSocketDebuggerUrl);
let id=0; const pend={}; const logs=[];
ws.onmessage = e => { const m=JSON.parse(e.data); if(m.id&&pend[m.id]){pend[m.id](m);delete pend[m.id];}
  if(m.method==='Runtime.consoleAPICalled') logs.push(m.params.type+': '+m.params.args.map(a=>a.value??a.description).join(' '));
  if(m.method==='Runtime.exceptionThrown') logs.push('EXC: '+JSON.stringify(m.params.exceptionDetails.exception?.description||m.params.exceptionDetails.text)); };
await new Promise(r=>ws.onopen=r);
const send=(method,params={})=>new Promise(r=>{const i=++id;pend[i]=r;ws.send(JSON.stringify({id:i,method,params}));});
await send('Runtime.enable'); await send('Page.enable');
await send('Emulation.setDeviceMetricsOverride',{width:1920,height:1080,deviceScaleFactor:1,mobile:false});
await send('Page.navigate',{url:'http://localhost:8765/index.html'});
await sleep(25000);
// press Up 5 times (-> 6x) via key events to verify input
for (let k=0;k<5;k++){ for (const type of ['rawKeyDown','keyUp']) await send('Input.dispatchKeyEvent',{type,key:'ArrowUp',code:'ArrowUp',windowsVirtualKeyCode:38}); await sleep(150);}
await send('Input.dispatchKeyEvent',{type:'rawKeyDown',key:'ArrowRight',code:'ArrowRight',windowsVirtualKeyCode:39});
await sleep(600);
const shot = await send('Page.captureScreenshot',{format:'png'});
fs.writeFileSync(process.argv[2], Buffer.from(shot.result.data,'base64'));
console.log(logs.join('\n'));
ws.close(); chrome.kill(); process.exit(0);
