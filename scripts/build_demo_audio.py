"""Original deterministic synthesized Foley and river/wind beds; no external audio.
Run with Python + numpy. WAV files are source assets, not generated at runtime.
"""
from pathlib import Path
import json, wave, hashlib
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'game/assets/audio'
OUT.mkdir(parents=True, exist_ok=True)
SR = 22050
RNG = np.random.default_rng(4104)
manifest = []

def noise(n, low, high):
    f = np.fft.rfftfreq(n, 1/SR)
    spectrum = np.fft.rfft(RNG.normal(0, 1, n))
    shape = (1-np.exp(-(f/max(low,1))**2)) * np.exp(-(f/high)**2)
    signal = np.fft.irfft(spectrum*shape, n)
    return signal/max(np.std(signal), .001)

def write(name, signal, peak=.6, loop=False):
    signal = np.asarray(signal)
    signal -= np.mean(signal, axis=0)
    if not loop:
        fade = min(180, len(signal)//8)
        signal[:fade] *= np.linspace(0,1,fade)[:,None] if signal.ndim==2 else np.linspace(0,1,fade)
        signal[-fade:] *= np.linspace(1,0,fade)[:,None] if signal.ndim==2 else np.linspace(1,0,fade)
    signal *= peak/max(abs(signal).max(), .0001)
    pcm = (signal*32767).astype('<i2')
    path = OUT/(name+'.wav')
    with wave.open(str(path),'wb') as wav:
        wav.setnchannels(2 if signal.ndim==2 else 1);wav.setsampwidth(2);wav.setframerate(SR);wav.writeframes(pcm.tobytes())
    manifest.append({'file':path.name,'seconds':round(len(signal)/SR,3),'peak_dbfs':round(20*np.log10(max(abs(signal).max(),1e-9)),2),'rms_dbfs':round(20*np.log10(np.sqrt(np.mean(signal**2))),2),'loop':loop,'sha256':hashlib.sha256(path.read_bytes()).hexdigest()})

for kind, base, grit in [('wood',185,.20),('stone',650,.52),('build',235,.30)]:
    for variant in range(2):
        t = np.arange(int(SR*.30))/SR
        f = base*(1+variant*.08)
        body = sum(np.sin(2*np.pi*f*r*t)*a*np.exp(-t/d) for r,a,d in [(1,1,.045),(1.71,.35,.023),(2.9,.16,.014)])
        body += grit*noise(len(t),900,6500)*np.exp(-t/.016)
        body += .12*noise(len(t),60,900)*np.exp(-t/.07)
        write(f'{kind}_{variant}',body,.58)

t=np.arange(int(SR*.09))/SR
write('ui',np.sin(2*np.pi*420*t)*np.exp(-t/.014)+.15*noise(len(t),600,4500)*np.exp(-t/.009),.28)
for name, notes, gap in [('gain',[660,880],.07),('complete',[330,440,550,660],.14),('reward',[440,550,660,880],.12)]:
    t=np.arange(int(SR*(len(notes)*gap+.6)))/SR
    sound=np.zeros_like(t)
    for i,f in enumerate(notes):
        dt=np.maximum(0,t-i*gap)
        envelope=(t>=i*gap)*(1-np.exp(-dt/.008))*np.exp(-dt/.19)
        sound+=envelope*(np.sin(2*np.pi*f*dt)+.22*np.sin(2*np.pi*f*2*dt))
    write(name,sound,.42)

# Integer-period modulation + periodic FFT noise avoids loop seams.
t=np.arange(SR*12)/SR
# Preserve the established wind/Foley random sequence; river has its own seed.
RNG.normal(0,1,(4,len(t)))
from river_audio import render_river
write('river',render_river(SR),.30,True)
wind=[]
for ch in range(2):
    wind.append(noise(len(t),80,1500)*(.5+.25*np.sin(2*np.pi*t/12+ch*.4))+.1*noise(len(t),1200,4800))
write('wind',np.stack(wind,axis=1),.28,True)
(OUT/'manifest.json').write_text(json.dumps({'author':'Original synthesis for RoxHistory; no third-party recordings or music','sample_rate':SR,'assets':manifest},indent=2),encoding='utf-8',newline='\n')
print(json.dumps(manifest,indent=2))
