# Recorded river source — v0.1.8 audio revision

User listening feedback on 2026-10-31 rejected the synthetic river as noise. This revision uses a real water recording and reduces the synthesized wind bed by 10dB. The developer did not claim physical-speaker/headphone listening.

- **gentle river flow**, Garuda1982, 2023-10-30. [Official source and CC0 declaration](https://freesound.org/people/Garuda1982/sounds/707576/).
- License: [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/). Source page permits copying, modification, distribution and commercial use. Attribution is preserved here for provenance.
- `gentle-river-flow-source.mp3`: publicly offered high-quality preview from the official CDN, unchanged. The login-gated original WAV was not downloaded. Recorded in Germany; this is generic water ambience, not a recording from Amsa.
- `gentle-river-flow-filtered.wav`: editable PCM source, original seconds10..36, high-pass90Hz/low-pass4500Hz, 22050Hz stereo16bit. Created with FFmpeg: `ffmpeg -ss 10 -i gentle-river-flow-source.mp3 -t 26 -af highpass=f=90,lowpass=f=4500 -ar 22050 -ac 2 -c:a pcm_s16le gentle-river-flow-filtered.wav`.
- `../../scripts/river_audio.py`: 24-second loop with a 2-second equal-power circular overlap. No artificial slow surge, waves, music or added animals.
- `../../scripts/build_demo_audio.py`: regenerates shipped WAVs and metadata. Run with Python + NumPy; FFmpeg is only needed to recreate the filtered input from the MP3.
- `provenance.json`: source URLs, edit parameters and input checksums. `verify_demo_audio.py` checks these inputs and the shipped PCM. Other11 sound assets remain byte-identical.

The A/B audition also included BurghRecords, [Gentle Stream Natural Stream Sound](https://freesound.org/people/BurghRecords/sounds/446019/), CC0. It is not included in the game. A was selected as the initial implementation assumption pending user preference, not represented as user approval.
