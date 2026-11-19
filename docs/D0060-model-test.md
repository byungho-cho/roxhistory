# D0060 · Z90000 model test · 0.2.259

Manual task, based on v0.2.258 / 4ecd7e7d7ee5385e3ccc94f692496086233108b0.
Instruction SHA-256: 9b933dd5cc179be47a571e74416c2f3cdf7abd58a76f77e77d42bf16bf2d631c.
Input: https://drive.google.com/drive/folders/114Cxc7kJuhLrA55mfhbusEOTgL8cxrCg
Final Figma: zkbflw9fCdAlWbphhw5pSS, 3656:6 / 3664:127 / 3662:150 / 3658:124.

## Changes

- Silver round flask opens the unchanged existing laboratory. Gold round Hangyeol immediately below opens Z90000; the performance shortcut moves down one row to avoid overlap.
- Independent preview controller reuses deployed RES-036 Hangyeol/Saebom, RES-009 Uram, and D0059 wildlife; no comparison-render model imports or modifications to hunt rules.
- Inline square category / round individual / ALL selectors. ALL is three allies or four CH1 animals; unsupported individual motions are disabled, mixed-group unsupported members remain idle.
- Full-width black 50% preview HUD, two-line status, separate battlefield and route switches. Silver full-motion button; gold/teal/dim motion states; eight round rate buttons and gold restart.
- Battlefield anchors and ally formation derive directly from deer_hunt_screen.gd. Camera directions match the hunt view; deployed model proportions remain intact. Enlarged transparent render targets retain pixel density and protect skill/root travel.
- Preview-local clock only. Native animal/root locomotion stays native; extracted resident locomotion uses native stride when available and a bounded two-cycle path for in-place clips. Skill/recoil roots remain native. Restart preserves category, selection, speed and switches.
- Responsive layout fills wide cover ratios, retaining two motion rows and separating the speed stack from restart.

## Verification

Godot 4.5.1 Compatibility renderer, injected touch down/up events:

- 1600×690 cover-like and 1440×1200 unfolded-like ratios: zero D0060 failures.
- All seven solos, ally ALL / animal ALL; all connected motions and disabled-motion rejection; local clocks at all eight speeds; restart; independent view/route toggles; ALL route stop under both views/all speeds.
- Render-target alpha bounds sampled during full/skill/charge/slam; no clipping in sampled poses. Bounds checks for controls and explicit speed/restart non-overlap.
- Actual hunt anchor, global Engine.time_scale preservation, back navigation/world restoration, and legacy laboratory entry verified.
- Evidence and executable check: canonical build/d0060/verify.gd, cover/open screenshots and verification JSON.

Physical Fold is unavailable: these are PC aspect-ratio renders and injected touch tests, not physical-device approval. Full gameplay and known failing legacy regressions are not claimed as passing. Android build/signature and remote-distribution verification are reported separately in the delivery result. No combat values, saves, audio policy or automatic monitoring changes.

Figma source icon PNGs and round SVGs are local in assets/ui/d0060; crops are used for selectors only. Background, silver rectangle, switches and brush reuse existing approved assets. Runtime never downloads Figma assets or uses reference screenshot backgrounds.
