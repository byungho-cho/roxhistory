"""Adopt the approved music master and author soft A303 UI/nature cues.
Run after build_demo_audio.py, or alone to update only these four runtime files.
Music bytes remain identical to the user-selected 44.1kHz master.
"""
from pathlib import Path
import hashlib,json,wave
import io
import numpy as np

ROOT=Path(__file__).resolve().parents[1]
RATE=22050
OUT=ROOT/'game/assets/audio'
LIBRARY=ROOT/'assets/audio'

def read_pcm(path):
    with wave.open(str(path),'rb') as w:
        rate=w.getframerate();channels=w.getnchannels()
        assert w.getsampwidth()==2
        samples=np.frombuffer(w.readframes(w.getnframes()),dtype='<i2').reshape(-1,channels).astype(float)/32768
    return rate,samples

def export(path,samples,rate=RATE,peak=.22):
    path.parent.mkdir(parents=True,exist_ok=True)
    samples=np.asarray(samples,dtype=float)
    if samples.ndim==1:samples=samples[:,None]
    samples-=samples.mean(axis=0)
    edge=min(int(rate*.004),len(samples)//8)
    samples[:edge]*=np.linspace(0,1,edge)[:,None]
    samples[-edge:]*=np.linspace(1,0,edge)[:,None]
    samples*=peak/max(float(np.max(np.abs(samples))),1e-8)
    buffer=io.BytesIO()
    with wave.open(buffer,'wb') as w:
        w.setnchannels(samples.shape[1]);w.setsampwidth(2);w.setframerate(rate)
        w.writeframes((samples*32767).astype('<i2').tobytes())
    data=buffer.getvalue()
    if path.exists():
        assert path.read_bytes()==data, 'Existing audio version changed; create a new version: '+str(path)
    else:path.write_bytes(data)

def describe(path):
    rate,x=read_pcm(path)
    return {'file':path.name,'sample_rate':rate,'channels':x.shape[1],'frames':len(x),
            'seconds':round(len(x)/rate,6),'peak_dbfs':round(20*np.log10(np.max(np.abs(x))),2),
            'rms_dbfs':round(20*np.log10(np.sqrt(np.mean(x*x))),2),
            'sha256':hashlib.sha256(path.read_bytes()).hexdigest()}

def build():
    manifest=json.loads((OUT/'manifest.json').read_text(encoding='utf-8'))
    catalog=json.loads((LIBRARY/'catalog.json').read_text(encoding='utf-8'))
    legacy=LIBRARY/'sfx/archived/ui_legacy/v001/ui.wav'
    if not legacy.exists():
        assert hashlib.sha256((OUT/'ui.wav').read_bytes()).hexdigest()=='77d3209608ad5d38cae44b99ae00bdcefd398861a6788c45608dbc6a222c9a0a'
        legacy.parent.mkdir(parents=True,exist_ok=True);legacy.write_bytes((OUT/'ui.wav').read_bytes())
    source=LIBRARY/'sfx/review/ui_soft_tap/v001/tap.wav'
    rate,tap=read_pcm(source)
    assert rate==44100
    n=np.arange(-24,25)
    h=2*(8500/rate)*np.sinc(2*(8500/rate)*n)*np.hanning(len(n));h/=h.sum()
    tap=np.stack([np.convolve(tap[:,ch],h,mode='same')[::2] for ch in range(tap.shape[1])],axis=1)
    ui=LIBRARY/'sfx/implemented/ui_soft_tap/v002/ui.wav'
    export(ui,tap,peak=.22)
    t=np.arange(int(.25*RATE))/RATE
    selected=np.zeros((len(t),2));selected[:len(tap)]+=tap*.85
    for delay,f,gain in [(.018,587.3295,.037),(.041,880.0,.016)]:
        dt=np.maximum(t-delay,0)
        tone=np.sin(2*np.pi*f*dt)+.12*np.sin(2*np.pi*f*2*dt)
        env=(t>=delay)*(1-np.exp(-dt/.007))*np.exp(-dt*27)
        selected+=gain*(tone*env)[:,None]
    select=LIBRARY/'sfx/implemented/region_select/v001/select.wav'
    export(select,selected,peak=.24)
    t=np.arange(int(.72*RATE))/RATE
    chirp=np.zeros_like(t)
    for delay,duration,base,span,level in [(.10,.15,1450,430,1),(.34,.18,1720,-290,.62)]:
        dt=t-delay;u=np.clip(dt/duration,0,1)
        frequency=base+span*np.sin(u*np.pi*.75)+35*np.sin(u*np.pi*3)
        phase=np.cumsum(2*np.pi*frequency/RATE)
        env=(dt>=0)*(dt<duration)*np.sin(np.pi*u)**2
        chirp+=level*env*(np.sin(phase)+.055*np.sin(2*phase))
    bird=LIBRARY/'ambience/implemented/soft_bird/v001/bird.wav'
    export(bird,chirp,peak=.18)
    music=LIBRARY/'bgm/approved/a303_starlight/v001/loop.wav'
    approved=next(a for a in catalog['assets'] if a['id']=='bgm.a303.starlight.v001')
    assert hashlib.sha256(music.read_bytes()).hexdigest()==approved['sha256']
    sources=[('ui.wav',ui,'sfx.ui.soft_tap.v002',False),
             ('select.wav',select,'sfx.region.select.v001',False),
             ('bird.wav',bird,'ambience.soft_bird.v001',False),
             ('a303_bgm.wav',music,approved['id'],True)]
    for name,path,aid,loop in sources:
        runtime=OUT/name;runtime.write_bytes(path.read_bytes())
        item=describe(runtime)
        item.update({'loop':loop,'asset_id':aid,'source':{'inputs':[{'path':path.relative_to(ROOT).as_posix(),'sha256':item['sha256']}]}})
        if loop:item['loop_begin']=0;item['loop_end']=approved['frames']
        manifest['assets']=[a for a in manifest['assets'] if a['file']!=name]+[item]
    for path,aid,status in [(legacy,'sfx.ui.legacy.v001','archived'),(ui,'sfx.ui.soft_tap.v002','implemented'),(select,'sfx.region.select.v001','implemented'),(bird,'ambience.soft_bird.v001','implemented')]:
        item=describe(path);item.pop('file')
        item.update({'id':aid,'path':path.relative_to(ROOT).as_posix(),'status':status,
                     'decision_date':'2026-11-02','listening_approval':False,
                     'provenance':{'method':'Original additive/modal synthesis','third_party_samples':False}})
        previous=next((a for a in catalog['assets'] if a['id']==aid),None)
        if previous and previous['sha256']==item['sha256']:
            item['status']=previous['status']
            item['listening_approval']=previous.get('listening_approval',False)
        catalog['assets']=[a for a in catalog['assets'] if a['id']!=aid]+[item]
    catalog['updated_date']='2026-11-02'
    catalog['status_definitions']['implemented']='게임에 연결했으며 실제 출력의 사용자 확인은 별도'
    catalog['integration_plan']['status']='implemented_pending_runtime_validation'
    (OUT/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8',newline='\n')
    (LIBRARY/'catalog.json').write_text(json.dumps(catalog,ensure_ascii=False,indent=2)+'\n',encoding='utf-8',newline='\n')
    return [describe(OUT/name) for name,_,_,_ in sources]

if __name__=='__main__':print(json.dumps(build(),ensure_ascii=False,indent=2))
