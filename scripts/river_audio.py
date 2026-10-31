"""Original quiet-flow synthesis. Editable source; no sampled third-party audio."""
import numpy as np

def render_river(sr=22050, seconds=12):
    rng=np.random.default_rng(7017)
    n=sr*seconds
    t=np.arange(n)/sr
    freqs=np.fft.rfftfreq(n,1/sr)
    def band(low, high):
        shape=(1-np.exp(-(freqs/low)**4))*np.exp(-(freqs/high)**4)
        x=np.fft.irfft(np.fft.rfft(rng.normal(size=n))*shape,n)
        return x/np.std(x)
    channels=[]
    for ch in range(2):
        # Fine continuous flow, without the old 3/4-second bass surges.
        bed=.52*band(420,3300)+.13*band(1800,5600)
        bed*=1+.025*np.sin(2*np.pi*t*7/seconds+ch)+.018*np.sin(2*np.pi*t*13/seconds)
        for _ in range(48):
            start=int(rng.uniform(0,n));duration=int(sr*rng.uniform(.045,.11))
            u=np.arange(duration)/sr
            frequency=rng.uniform(1100,2400)
            phase=2*np.pi*(frequency*u-1800*u*u)
            envelope=np.sin(np.pi*np.arange(duration)/duration)**2*np.exp(-u*22)
            ripple=np.sin(phase)*envelope*rng.uniform(.09,.24)
            bed[(start+np.arange(duration))%n]+=ripple
        channels.append(bed)
    return np.stack(channels,axis=1)
