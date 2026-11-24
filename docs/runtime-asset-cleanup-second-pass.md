# Runtime asset audit: second source pass (optimized 313 review)
- Removed unreferenced crickets WAV; removed old d0069 intro SFX, which the Android preset already excluded and which active code loads from d0070 instead.
- Retained wood-hit PCM and the approved stone, demolition, and construction clips. Removed three older generated clips that the soundscape loaded and unconditionally overwrote before interactivity; no cue mapping change.
- Moved the four CC0 recorded master WAVs, provenance and license notes to art-source/audio/recorded-actions-v001. The Godot tree and Android install no longer contain master WAVs.
- Removed d0056 duplicate Han timeline; the active preview/production timeline consumer has a fixed d0057 directory. Preserved d0056 provenance outside runtime.
- Other noisy names are not grounds for deletion: apparent trial resident atlases are dynamically loaded; the preview model is used by the shipped development parry lab; the three candidate-named BGMs and terrain/result fallbacks are active.
- Android 313 package inventory: these classes account for at least 536,298 compressed bytes across 18 package entries before this change; d0069 already saved zero APK bytes. Texture alias optimization is a separate packaging pass.

Verified with the isolated Godot project: clean import, title startup, four exact approved work cue paths resolved and played from the unchanged source streams, all five scene music resources found, all six retired logical resource paths absent. Explicit sound-switch testing exercised the cue objects, not playback on physical Android hardware.
