# D0063 · 0.2.262 Android PCK patch

Base: D0062 / 0.2.261 / 841f72f281dc1b03adff2b28dd5b2ad738be9379.
Instruction: https://drive.google.com/file/d/1sqrjuRQ_b8NSpslS-799IBwE1OBV2Uqc/view
Figma: zkbflw9fCdAlWbphhw5pSS / 3698:602; Ruby 2999:983.

Only Z90000 wildlife mappings and common control UI change. Wildlife buttons are idle/walk/run/attack/hit/skill/full in one row. Deer attack=antler_ram, skill=front_hoof_slam; boar attack=basic_attack, skill=charge_ram or heavy_charge_ram. Full playlists use the six mapped items once each (locomotion retains the existing two-cycle duration); no front_hoof_kick and no duplicate native clip. Existing files and the legacy wildlife lab/hunt catalog are untouched. Paired models and ALL share the existing preview clock.

Selectors are 88.4 design pixels (existing 68 ×1.3), speed controls 96, no 1.25 rate. Ruby restart uses the Figma-exported 96×96 asset with the existing ↻ glyph, aligned to the speed column; both use 80% opacity. Low-height screens scale the speed/restart column together to preserve equal visual size and avoid overlap; full design geometry stays 96. Status and selector positions follow the Figma HUD, existing tokens/images are reused. Do not import reference boar artwork as a runtime model.

Verification: 1600×690 and 1440×1061 actual desktop renders, injected touch checks; seven labels/order, deer/boar mappings, unique full playlists, paired synchronization, all retained rates, restart state, ruby texture/opacity/geometry, selector scaling, model/label bounds and ALL/other solo preservation. Physical Fold is not available; these are not physical-device results. Full gameplay/legacy regressions are not claimed as passing. No running A/B/C or meadow/campfire changes; monitoring stays paused.

Publish through the existing signed PCK flow with predecessor-delta reconstruction and remote signature/hash verification. No new APK is required.
