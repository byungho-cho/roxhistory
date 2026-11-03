"""Reproducible dry timber and short mineral contact cues, original synthesis, no samples."""
from pathlib import Path
import numpy as np,wave,json,hashlib,shutil
root=Path(__file__).resolve().parents[1];runtime=root/'game/assets/audio';bank=root/'assets/audio/sfx/implemented/gather_contact/v002';bank.mkdir(parents=True,exist_ok=True)
old=root/'assets/audio/sfx/archived/gather_contact/v001';old.mkdir(parents=True,exist_ok=True)
sr=22050;rng=np.random.default_rng(110327);items=[]
for kind in ['wood','stone']:
 for v in range(2):
  name=f'{kind}_{v}.wav';original=runtime/name
  if not (old/name).exists():shutil.copyfile(original,old/name)
  t=np.arange(int(sr*.24))/sr;noise=rng.normal(size=len(t))
  if kind=='wood':
   sound=sum(a*np.sin(2*np.pi*f*(1+v*.045)*t)*np.exp(-t/d) for f,a,d in [(180,1,.032),(395,.48,.022),(870,.18,.012)])
   crack=np.concatenate(([0],np.diff(noise)))*np.exp(-t/.006)*.16
   sound+=crack+.08*np.convolve(noise,np.ones(5)/5,'same')*np.exp(-t/.038)
  else:
   sound=sum(a*np.sin(2*np.pi*f*(1+v*.035)*t)*np.exp(-t/d) for f,a,d in [(890,.55,.027),(1470,.32,.020),(2360,.16,.014)])
   sound+=.27*noise*np.exp(-t/.008)+.09*np.sin(2*np.pi*220*t)*np.exp(-t/.025)
  sound*=1-np.exp(-t/.0007);sound[-120:]*=np.linspace(1,0,120);sound-=sound.mean();sound*=.46/max(abs(sound));pcm=(sound*32767).astype('<i2')
  path=bank/name
  with wave.open(str(path),'wb') as f:f.setnchannels(1);f.setsampwidth(2);f.setframerate(sr);f.writeframes(pcm.tobytes())
  shutil.copyfile(path,original)
  items.append({'file':name,'seconds':len(t)/sr,'sample_rate':sr,'loop':False,'peak_dbfs':round(20*np.log10(max(abs(sound))),2),'rms_dbfs':round(20*np.log10(np.sqrt(np.mean(sound**2))),2),'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'source':{'method':'Original deterministic modal/noise synthesis, no third-party samples','inputs':[{'path':str(path.relative_to(root)).replace('\\','/'),'sha256':hashlib.sha256(path.read_bytes()).hexdigest()}]}})
p=runtime/'manifest.json';o=json.loads(p.read_text());repl={i['file']:i for i in items};o['assets']=[repl.get(i['file'],i) for i in o['assets']];p.write_text(json.dumps(o,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
p=root/'assets/audio/catalog.json';o=json.loads(p.read_text(encoding='utf-8'));o.setdefault('gather_contact',{})['v002']={'status':'implemented_pending_listening','path':str(bank.relative_to(root)).replace('\\','/'),'source':'Original synthesis; no third-party samples','date':'2026-11-03','files':items};p.write_text(json.dumps(o,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
(bank/'README.md').write_text('Original deterministic synthesized contact sounds. Source: scripts/build_gather_contact.py. No third-party recordings. Runtime 22050 Hz mono PCM16. Old runtime cues preserved in archived/gather_contact/v001. Listening approval pending.\n',encoding='utf-8')
print(json.dumps(items,indent=2))
