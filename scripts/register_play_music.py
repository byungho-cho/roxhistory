"""Register decoded selected MP3. This PCM derivative is NOT a lossless master.

Decode first with FFmpeg: -i <approved>/listen.mp3 -c:a pcm_s16le -ar 48000
game/assets/audio/play_bgm.wav. Encoder-delay trimming is provided by FFmpeg.
"""
from pathlib import Path
import hashlib,json,wave
root=Path(__file__).resolve().parents[1]
source=root/'assets/audio/bgm/approved/first_embers_lightly_bright/v001/listen.mp3'
runtime=root/'game/assets/audio/play_bgm.wav'
digest=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
assert digest(source)=='6a3491203c1d87e5946c1a8fe13b43a4185e177d5105454c397d36ecc3f78120'
with wave.open(str(runtime),'rb') as w:
    frames=w.getnframes();rate=w.getframerate()
    assert frames==3544615 and rate==48000 and w.getsampwidth()==2 and w.getnchannels()==2
entry={'file':runtime.name,'seconds':frames/rate,'sample_rate':rate,'loop':True,'loop_begin':0,'loop_end_exclusive':frames,'sha256':digest(runtime),'source':{'method':'FFmpeg PCM16 decoding of approved lossy MP3; not original WAV master; no recomposition or time stretching','inputs':[{'path':source.relative_to(root).as_posix(),'sha256':digest(source)}]}}
p=root/'game/assets/audio/manifest.json';data=json.loads(p.read_text(encoding='utf-8'));data['assets']=[x for x in data['assets'] if x['file']!=runtime.name]+[entry];p.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
p=root/'assets/audio/catalog.json';data=json.loads(p.read_text(encoding='utf-8'));data['first_embers_play']={'id':'bgm.first_embers.lightly_bright.v001','status':'approved_implemented_pending_listening','source_commit':'518001ce5c55d054ce27089d734f4ec9944d5bbb','runtime':entry,'scene':'play only; A303 unchanged','master_status':'WAV not yet received','date':'2026-11-03'};p.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps(entry,indent=2))
