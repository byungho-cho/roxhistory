"""Loop a CC0 field recording; editable PCM and source attribution are in assets/audio-sources."""
from pathlib import Path
import wave
import numpy as np

def render_river(sr=22050, seconds=24):
    source=Path(__file__).resolve().parents[1]/'assets/audio-sources/gentle-river-flow-filtered.wav'
    with wave.open(str(source),'rb') as wav:
        assert wav.getframerate()==sr and wav.getnchannels()==2 and wav.getsampwidth()==2
        pcm=np.frombuffer(wav.readframes(wav.getnframes()),dtype='<i2').reshape(-1,2).astype(float)/32768
    n=int(sr*seconds);fade=sr*2
    assert fade<n and n+fade<=len(pcm)
    # End at source[2s], immediately before the loop's first sample. Equal-power
    # overlap keeps the natural ripples without a fade-to-silence or wave swell.
    t=np.linspace(0,np.pi/2,fade)[:,None]
    return np.concatenate([pcm[fade:n],pcm[n:n+fade]*np.cos(t)+pcm[:fade]*np.sin(t)])
