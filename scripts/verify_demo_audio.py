"""Validate shipped PCM sources, provenance and seamless-bed boundary energy."""
from pathlib import Path
import array, hashlib, json, math, wave
root = Path(__file__).resolve().parents[1]/'game/assets/audio'
manifest=json.loads((root/'manifest.json').read_text(encoding='utf-8'))
results=[]
for item in manifest['assets']:
    path=root/item['file']
    for source in item.get('source',{}).get('inputs',[]):
        original=(root.parents[2]/source['path']).resolve()
        assert original.is_relative_to((root.parents[2]/'assets/audio-sources').resolve()),original
        assert hashlib.sha256(original.read_bytes()).hexdigest()==source['sha256'],original
    assert hashlib.sha256(path.read_bytes()).hexdigest()==item['sha256'],path
    with wave.open(str(path),'rb') as wav:
        assert wav.getsampwidth()==2 and wav.getframerate()==22050,path
        channels=wav.getnchannels();pcm=array.array('h',wav.readframes(wav.getnframes()))
    peak=max(abs(x) for x in pcm)/32768
    rms=math.sqrt(sum(x*x for x in pcm)/len(pcm))/32768
    assert .01<rms<.4 and peak<.8,(path,rms,peak)
    seam=None
    if item['loop']:
        jumps=sorted(abs(pcm[i]-pcm[i-channels]) for i in range(channels,len(pcm)))
        seam=max(abs(pcm[c]-pcm[-channels+c]) for c in range(channels))
        assert seam<jumps[int(len(jumps)*.999)]+1,(path,seam)
    results.append({'asset':path.name,'peak_dbfs':round(20*math.log10(peak),2),'rms_dbfs':round(20*math.log10(rms),2),'loop_boundary_delta':seam})
print(json.dumps({'assets':len(results),'failed':[],'results':results},indent=2))
