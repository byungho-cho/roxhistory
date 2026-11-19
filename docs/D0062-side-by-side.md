# D0062 · 0.2.261 patch

Instruction: https://drive.google.com/file/d/1ATpjuoV9pxS9ML_YbjF8sP6xoQ4c93VE/view
Results folder: https://drive.google.com/drive/folders/1IyNylES8j2ySnQQ5HagrSwZgdKwJN5p0
Baseline: 0.2.260 / 23e51415b793e02aab937bed1a9f3c62623db253.

Only Z90000 individual Hangyeol and four wildlife comparisons change: original left, lightweight right, with the requested abbreviated polygon labels above. Both adapters share one preview clock and all controls, identical camera/light/model scale, separate render targets. Labels stay below the HUD and low-height screens adapt both actors equally to contain the motions. The former single-model toggle is removed. Uram/Saebom solos, ALL models/formation, actual hunting and motion sources remain unchanged. No running A/B/C, asset replacement or new automation.

Checks: injected touch model/motion/rate/restart/view/route operations; both rendered actors visible at sampled motion phases, map bounds, labels and mutual non-overlap; original ALL/other solos/back behavior. Actual render sizes and failures are recorded in canonical build/d0062. Physical Fold is unavailable; desktop ratio/injected-input checks are not claimed as device verification. Full legacy regression suite is not claimed as passing.

Release uses the existing signed PCK channel, with exact reconstruction checks for available predecessor deltas. No new native runtime or APK is needed. Directly installed 0.2.260 has no cached cumulative predecessor, so select_delta must return empty and choose the cumulative patch; validate its signature/hash, mount it through the embedded 0.2.260 updater and load the patched model screen. Existing 0.2.260 APK and older complete APK/EXE pair remain available. Do not change download architecture or APK catalog limits.
