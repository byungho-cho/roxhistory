# Village sound v0.2 selected integration
## Final user selection
Apply ONLY stone-gather-v02.wav and construction-work-v02.wav.
Keep wood-hit.wav and gain.wav at v0.1; no other sounds change.

## Implementation
Branch: codex/village-sfx-v02-selected
Worktree: D:\workspace\roxhistory-village-sfx-v02
Base commit: c21e3f6 (active development 0.2.128 at inspection)
Observed published local manifest: 0.2.127 ff09385.
Existing developer checkout untouched; no merge, push, build or release performed.

soundscape.gd overrides only recorded_stone and recorded_build after loading previous sound map.
Existing work voice, timing, stop/cancel, sound toggle, background and popup policies remain unchanged.
Two WAVs are 44.1kHz mono PCM16, duration 1s and 2s, peak approximately -6dB.
New generation files and v0.1 references remain in shared-handoff.

## Verification
Godot 4.5.1 headless import: exit 0, no ERROR lines.
Independent village_sfx_v02_tests: 19 assertions pass, including exact resource selections, wood/gain preservation, playback selection, no voice stacking, cancel/mute/popup/background handling.
Exit cleanup warnings remain: ObjectDB instances / 2 resources in use. Not a clean aggregate pass.
recorded_action_audio_tests: 28/31 pass; 3 demolition fixture failures reproduced unchanged on base source.
building_audio_v0151_tests: construction fixture failure and array-index error reproduced on base source.
No live listening or Android gameplay QA performed.

## Developer action
Review/apply this local branch changes to current development branch, retain all newer work.
Run game scene listening and repeated gathering/construction checks before patch release.
Do not apply wood-gather-v02 or gather-complete-v02.
Prefer compatible PCK patch; no full APK unless technically required.

