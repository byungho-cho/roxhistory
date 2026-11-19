# D0061 R03 — prepared changes, release held

Manual instruction: https://drive.google.com/file/d/15SogeMEnaaf9OoK78SQMJZ4pA1RiSSyq/view
Folder: https://drive.google.com/drive/folders/1GftJKlVfH0yU4UNOIEGUpFBAj5B5JwiM
Baseline: D0060 / 0.2.259 / 9aa64e83753ac9b27a70a43ab9de5adcb5968f3a.
Remote main was still 4ecd7e7 (0.2.258); the released D0060 commit is preserved as the task parent.
R03 supersedes the initially fetched instruction. Local R03 text SHA-256: ec63305fe13ff844ff19d32f1879ab0a5145dda04814905a3d2dda5388bb100c.

## Release gate

REQ-040 lightweight wildlife GLBs are not present in the provided folder at final manual readback. Do not substitute models, expose unfinished animal comparison slots, or publish this partial patch. All four originals remain unchanged. REQ-042 motion reform is separate. No release version bump, build/release publication, merge or monitoring activation is performed here.

## Prepared implementation

- Z90000 Hangyeol A/B toggle, same slot/camera/size/lighting/clock/rate/motion. A is byte-identical to deployed d0057/hangyeol-req035.glb (60,037 triangles); B has 11,979 triangles and the same animation names/skeleton. Only the lab supplies an optional comparison path; actual hunting and its jump model remain unchanged. Group captions identify B when retained in ALL.
- Meadow clean plate and transparent tent are separate runtime layers. Tent source rectangle is (872,285,137,92) in 1280×720; independent contact shadow and masked fire/plume remain behind the original boar.
- Original hunt-meadow-idle-loop.ogv is unmodified. A 200×300 temporal minimum reference from 28 source samples at 6 fps suppresses stationary terrain/compression residue; an orange-keyed fire aperture and neutral positive-difference plume produce alpha without carrying the old rectangular scenery. The plume base is re-anchored to the fire. No replacement video or composite-reference background is used.
- Same video player starts on entry and continues through boar entrance, completion, skip and resize; it loops normally. Reduced-motion mode shows a masked existing still rather than starting the video.
- Intro backdrop has its own invisible DemoButton behind the existing controls. Touch release/mouse click invokes existing finish_intro; its leaving guard and transition cover prevent duplicate navigation and input spill. Existing skip/music/sound controls remain independent.
- Unfolded bag header/back and bottom-right close remain fixed; only the middle grid scrolls. Eight columns, safe area/common inset and the cover layout remain. Resize recalculates list/rail/thumb and clamps scroll offset; no zero-offset division.
- BGM mix is absolute .90 (the D0029 pre-reduction reference) × .70 = .63 bus gain before the saved volume. Repeated apply does not compound. SFX/combat/master/user settings and switches are unchanged.
- PCK-only HTTP total timeout is disabled during transfer; a monotonic 30-second idle window resets only when body-byte count increases. Metadata and native APK timeout policies, cancel, retry, delta fallback and size/hash checks are unchanged. Existing installed bootstrap code is not retroactively replaced in-memory; distribute the eventual updated APK as instructed for its updater changes.

## Validation and limitations

Godot 4.5.1 Compatibility renderer; final local checks in canonical build/d0061:

- Cover render 1600×690; unfolded-like render 1440×1061 (1200 height requested but Windows work area caps it). No claim of a physical Fold run.
- UI/input suite: both ratios 0 failures. A/B same camera/scale/position/time/rate/motion, matching skeleton positions, B visible; long 128-slot bag, 8 columns, fixed controls, cover/open geometry changes; BGM preferences/mute/non-compounding; continuous camp entry/skip/loop/reduced-motion; native GUI touch and mouse intro skip with sound-control exclusion and repeated mixed events.
- A dedicated alpha render samples five video times: nonzero output stays inside the fire/plume aperture, not the old scene rectangle. Composite screenshots manually inspected at both ratios. Physical Fold clipping/subjective plume quality remains unverified.
- Real local HTTP integration: continuous body progress completed in about 40.1 seconds; a stalled body failed after about 30.1 seconds idle. HTTP error and corrupt hash were rejected, cancel/retry completed, bad delta automatically fell back to a valid cumulative body. Unit deadline checks include no progress/decreasing byte counts and new-byte reset. Test requests use a local transport override and isolated cache; production trust validation is unchanged.
- Import/parse and diff checks passed. Full gameplay/known legacy regressions and physical-device performance are not claimed as passing. No APK build is reported as successful because release is held for the missing assets and final combined review.

Pending: receive all four REQ-040 GLBs, validate their triangle counts/rigs/motions and same-condition A/B comparison, finish combined validation, then assign the next release version and run the existing Android build/sign/publish/update verification flow. Automatic monitoring remains paused until explicit user ON.
