# Main integration after 0.2.279

## Result

- Main advances from the 0.2.258 development line to tested 0.2.279 (`dbf8198c09d58e1032029b57d214bfa6bec0e550`).
- All existing local and fetched remote branch tips are ancestors of the integration commit. No branches, tags, release records or old commits are deleted.
- Current application/build source tree is byte-for-byte identical to 0.2.279. This is a source/history consolidation, not a new application release.
- Older experimental, fixture and pre-rebuild branches are **history-only merges**. Their source remains available through the recorded parent commits; their old runtime switches, versions, temporary APK channels and unfinished models are not activated in the current tree.
- This policy deliberately avoids resurrecting superseded game behavior. It does not claim that every historical alternative is enabled in the current game.

## Local work preservation

Tracked working changes were captured with `git stash create` into named snapshot branches without changing the original worktree or index. Untracked attachments, handoff folders and videos were not staged.

- `codex/main-integration-snapshot-root-279`: `d75b537ef76edb53a032348e66ad952f52be3503` from `D:/workspace/roxhistory`; original working/index status unchanged.
- `codex/main-integration-snapshot-normal-279`: `b061006d0a773e35750d4199b504fe824da046d2` from `D:/workspace/roxhistory-normal-development`; original working/index status unchanged.
- `codex/main-integration-snapshot-sfx-279`: `82fc4836f09de25c3ffacc981299276a31900afe` from `D:/workspace/roxhistory-village-sfx-v02`; original working/index status unchanged.

## Verification

- `git diff --exit-code codex/duel-flow-279 HEAD` was empty immediately after the history merges. Subsequent additions are this documentation only.
- `git for-each-ref --no-merged HEAD refs/heads refs/remotes/origin` returned no branches.
- No executable is rebuilt or republished: game functionality, version, signing material and the tested 279 distribution remain unchanged.
- Existing release verification remains scoped to its recorded tests. The known Uram graphics-harness shutdown crash and polish-test resource warning are not declared fixed by this merge.

## Historical source references

Each listed commit retains its complete original tree and history. See the JSON audit for changed files and unique commit subjects.

| Branch/reference | Commit | Treatment |
| --- | --- | --- |
| `codex/android-install-local-fixture` | [`ee6eecee9d62`](https://github.com/byungho-cho/roxhistory/tree/ee6eecee9d6228aa8d504e4860d5040a897d29c9) | Historical source preserved; current 279 runtime retained |
| `codex/android-install-session-fix` | [`165c30026eeb`](https://github.com/byungho-cho/roxhistory/tree/165c30026eeb94220d961a9d6a8915a0d6eab549) | Historical source preserved; current 279 runtime retained |
| `codex/android-install-test-target` | [`fcaebef16eb4`](https://github.com/byungho-cho/roxhistory/tree/fcaebef16eb4d62384fcb7d71555c12898b71023) | Historical source preserved; current 279 runtime retained |
| `codex/android-pck-update-test`, `origin/codex/android-pck-update-test` | [`d244728ab6e4`](https://github.com/byungho-cho/roxhistory/tree/d244728ab6e4a8c8406707fb11ed1019d261d4e6) | Historical source preserved; current 279 runtime retained |
| `codex/d0013-resident-v02-dev`, `origin/codex/d0013-resident-v02-dev` | [`a471a935130b`](https://github.com/byungho-cho/roxhistory/tree/a471a935130b1fcd49108118c7b5f13cc87eb7f6) | Historical source preserved; current 279 runtime retained |
| `codex/d0016-local-patch-probe`, `origin/codex/d0016-local-patch-probe` | [`575bde41fc0c`](https://github.com/byungho-cho/roxhistory/tree/575bde41fc0c386f9699c81d4299cade810f108c) | Historical source preserved; current 279 runtime retained |
| `codex/d0036-lab` | [`88d03a476218`](https://github.com/byungho-cho/roxhistory/tree/88d03a4762182e41ced3e8be1cb3e6cd68f2560f) | Historical source preserved; current 279 runtime retained |
| `codex/d0036-patch` | [`6aeaa03fdba5`](https://github.com/byungho-cho/roxhistory/tree/6aeaa03fdba5f072b63ab52fc66411da68770fa2) | Historical source preserved; current 279 runtime retained |
| `codex/far-animal-refresh-fold` | [`d87533b3fc32`](https://github.com/byungho-cho/roxhistory/tree/d87533b3fc32650025e633efe8dc07eb9c090739) | Historical source preserved; current 279 runtime retained |
| `codex/farm-clock-redraw` | [`3ed2cd2d6070`](https://github.com/byungho-cho/roxhistory/tree/3ed2cd2d607032a48017d00df90557fe9866d7b1) | Historical source preserved; current 279 runtime retained |
| `codex/farm-clock-ui-probe` | [`6459a6384abb`](https://github.com/byungho-cho/roxhistory/tree/6459a6384abb67630b5abadda4fc08fcd196f89f) | Historical source preserved; current 279 runtime retained |
| `codex/fold-drag-trace` | [`51d43a74f301`](https://github.com/byungho-cho/roxhistory/tree/51d43a74f301fa3bf6db4d63bfc2f60bdb7646a5) | Historical source preserved; current 279 runtime retained |
| `codex/intro-bundle-reference-20261111` | [`159b250b2ae9`](https://github.com/byungho-cho/roxhistory/tree/159b250b2ae973bc4d8e0df57c7b5c48f6c3289f) | Historical source preserved; current 279 runtime retained |
| `codex/patch-client-0.2.97`, `origin/codex/patch-client-0.2.97` | [`e5fc25a1a306`](https://github.com/byungho-cho/roxhistory/tree/e5fc25a1a306091221f898261187951fb7ab12d4) | Historical source preserved; current 279 runtime retained |
| `codex/patch-client-0.2.99`, `origin/codex/patch-client-0.2.99` | [`72b92f7ed086`](https://github.com/byungho-cho/roxhistory/tree/72b92f7ed08647dce39a0f68f4bbdfd5567445f0) | Historical source preserved; current 279 runtime retained |
| `codex/performance-benchmark-0.2.91`, `origin/codex/performance-benchmark-0.2.91` | [`36e3fccb761a`](https://github.com/byungho-cho/roxhistory/tree/36e3fccb761a99561f6062bbde82bc71c62d3eb2) | Historical source preserved; current 279 runtime retained |
| `codex/performance-installer`, `origin/codex/performance-installer` | [`9d973dba0c78`](https://github.com/byungho-cho/roxhistory/tree/9d973dba0c78105fc419b5c0a4d235c573e5a070) | Historical source preserved; current 279 runtime retained |
| `codex/performance-t0`, `origin/codex/performance-t0` | [`897d6b54ee6f`](https://github.com/byungho-cho/roxhistory/tree/897d6b54ee6f7c7b066ca99c2a88569e3d7f3ffa) | Historical source preserved; current 279 runtime retained |
| `codex/performance-t1`, `origin/codex/performance-t1` | [`2cf8c39653c0`](https://github.com/byungho-cho/roxhistory/tree/2cf8c39653c04a6894c66cb22f53123e687b924f) | Historical source preserved; current 279 runtime retained |
| `codex/performance-t1-r2`, `origin/codex/performance-t1-r2` | [`beb9d403e244`](https://github.com/byungho-cho/roxhistory/tree/beb9d403e244724ba5d8a069e6d744a0c191529e) | Historical source preserved; current 279 runtime retained |
| `codex/performance-t2`, `origin/codex/performance-t2` | [`b2d82aca54dc`](https://github.com/byungho-cho/roxhistory/tree/b2d82aca54dc3e369a78b28fc471b285952d1011) | Historical source preserved; current 279 runtime retained |
| `codex/performance-t3`, `origin/codex/performance-t3` | [`ebc06d40d492`](https://github.com/byungho-cho/roxhistory/tree/ebc06d40d49262187e0b6a8f56f80ac62022c192) | Historical source preserved; current 279 runtime retained |
| `codex/resident-render-trial`, `origin/codex/resident-render-trial` | [`a6195321a6f0`](https://github.com/byungho-cho/roxhistory/tree/a6195321a6f02d070fe98c70507fe3d39651f508) | Historical source preserved; current 279 runtime retained |
| `codex/resident-study-review`, `origin/codex/resident-study-review` | [`f8ba0ad72fc0`](https://github.com/byungho-cho/roxhistory/tree/f8ba0ad72fc08d7c8fc956a59638926ffa67861d) | Historical source preserved; current 279 runtime retained |
| `codex/resident-walk-6-vs-12` | [`904dafcdaad5`](https://github.com/byungho-cho/roxhistory/tree/904dafcdaad5f816f28a9b34d0095572730bfe51) | Historical source preserved; current 279 runtime retained |
| `codex/unassigned-building-zzz` | [`373a45ace800`](https://github.com/byungho-cho/roxhistory/tree/373a45ace80063205582b40cb252a03ff905330a) | Historical source preserved; current 279 runtime retained |
| `codex/upgrade-asset-cache` | [`e6aa84599158`](https://github.com/byungho-cho/roxhistory/tree/e6aa8459915817f21862028d54c8db239daa50ad) | Historical source preserved; current 279 runtime retained |
| `codex/upgrade-asset-cache-probe` | [`c680c4cdf5ed`](https://github.com/byungho-cho/roxhistory/tree/c680c4cdf5ed1f1d95148046d863c28ef24c264b) | Historical source preserved; current 279 runtime retained |
| `origin/assets/farm-20261108` | [`3f17c6b75fe2`](https://github.com/byungho-cho/roxhistory/tree/3f17c6b75fe2af6808f9ab9557755cf8012fa660) | Historical source preserved; current 279 runtime retained |
| `origin/assets/farm-separated-20261108` | [`12b33359729d`](https://github.com/byungho-cho/roxhistory/tree/12b33359729d3d2dd91c5c9c3050e3ffef67f9a6) | Historical source preserved; current 279 runtime retained |
| `origin/assets/history-continuous-30s-v0.2.94-20261111` | [`53de656c91db`](https://github.com/byungho-cho/roxhistory/tree/53de656c91dbb7f65b7da1efdb4d742ef36922bb) | Historical source preserved; current 279 runtime retained |
| `origin/assets/hunting-match-update-20261112` | [`bd85f72cef30`](https://github.com/byungho-cho/roxhistory/tree/bd85f72cef3027bf3f4f1b78f2380a0100156128) | Historical source preserved; current 279 runtime retained |
| `origin/assets/hunting-separated-v001` | [`a426690bc342`](https://github.com/byungho-cho/roxhistory/tree/a426690bc34297e1c2f80c83dcaeaa2c9b58283c) | Historical source preserved; current 279 runtime retained |
| `origin/assets/hunting-ui-final-20261111` | [`266eda5a3222`](https://github.com/byungho-cho/roxhistory/tree/266eda5a3222618e9456718381a78a9fe8c2bbb2) | Historical source preserved; current 279 runtime retained |
| `origin/assets/menu-title-handoff-20261109` | [`de1f8016128e`](https://github.com/byungho-cho/roxhistory/tree/de1f8016128e001e20d6a2b18352f0f98e8786e4) | Historical source preserved; current 279 runtime retained |
| `origin/assets/residents-3d-reference-20261103` | [`e1f91528dd82`](https://github.com/byungho-cho/roxhistory/tree/e1f91528dd823cdc2c9787102ba07b61b5a4b13e) | Historical source preserved; current 279 runtime retained |
| `origin/assets/s10100-era-chapters-v002` | [`a1c37276fef7`](https://github.com/byungho-cho/roxhistory/tree/a1c37276fef78daf2158a42b4db7ed7f4720440e) | Historical source preserved; current 279 runtime retained |
| `origin/assets/s10100-intro-samples-20261110` | [`41a726d5d6ba`](https://github.com/byungho-cho/roxhistory/tree/41a726d5d6baeb38b2f9de7f883a3e91d44ef10e) | Historical source preserved; current 279 runtime retained |
| `origin/assets/upgrade-sign-tutorial-hand-v001` | [`d4e6c979e9a4`](https://github.com/byungho-cho/roxhistory/tree/d4e6c979e9a4f21724dc154aa61e5338d730f9ae) | Historical source preserved; current 279 runtime retained |
| `origin/audio/approved-bgm-20261101` | [`b578cffab38f`](https://github.com/byungho-cho/roxhistory/tree/b578cffab38fb435b6d96a808d95748372a5c206) | Historical source preserved; current 279 runtime retained |
| `origin/audio/first-embers-lightly-bright-20261103` | [`518001ce5c55`](https://github.com/byungho-cho/roxhistory/tree/518001ce5c55d054ce27089d734f4ec9944d5bbb) | Historical source preserved; current 279 runtime retained |
| `origin/codex/final-intro-35s-20261111` | [`641097350fa9`](https://github.com/byungho-cho/roxhistory/tree/641097350fa981e21d58b53527923b5702065b77) | Historical source preserved; current 279 runtime retained |
| `origin/demo/android-first-playable` | [`98f1b1c34bc9`](https://github.com/byungho-cho/roxhistory/tree/98f1b1c34bc978fb3e112958b3cd9d7f5d476dc4) | Historical source preserved; current 279 runtime retained |
| `origin/demo/android-v0.1.0` | [`a8d572a8a975`](https://github.com/byungho-cho/roxhistory/tree/a8d572a8a975e69491ff478f867a841d7e3732d4) | Historical source preserved; current 279 runtime retained |
| `origin/demo/stage1-riverside` | [`3236cf7b1b12`](https://github.com/byungho-cho/roxhistory/tree/3236cf7b1b1252cc6d43e895af71e3c988c11da3) | Historical source preserved; current 279 runtime retained |
| `origin/design/presentation-refresh` | [`845a911dc324`](https://github.com/byungho-cho/roxhistory/tree/845a911dc32482ccbc3bbdc6e5e39d6eb4cca62c) | Historical source preserved; current 279 runtime retained |
| `origin/design/resident-woodcutter-study` | [`0e72d4afb7ce`](https://github.com/byungho-cho/roxhistory/tree/0e72d4afb7ce6e25ae22d5ae790869329a8ec0ee) | Historical source preserved; current 279 runtime retained |
| `origin/design/s40000-assets-20261102` | [`424b2cb37086`](https://github.com/byungho-cho/roxhistory/tree/424b2cb37086a7fbb5483b64e754d13b125ad8d0) | Historical source preserved; current 279 runtime retained |
| `origin/design/visual-direction-1-enhanced` | [`be1cba2d9cbb`](https://github.com/byungho-cho/roxhistory/tree/be1cba2d9cbbbbea0f84b02dd39929d748f9da0b) | Historical source preserved; current 279 runtime retained |
| `origin/dev/v0151-planned-update-20261107` | [`105ac2271f6b`](https://github.com/byungho-cho/roxhistory/tree/105ac2271f6bd17dc73c728f97d14a8ed7dfa210) | Historical source preserved; current 279 runtime retained |
| `origin/dev/village-systems-20261106` | [`df9c0d5aeaee`](https://github.com/byungho-cho/roxhistory/tree/df9c0d5aeaee2b2dbd959aced6c96ba042a28e03) | Historical source preserved; current 279 runtime retained |
| `origin/docs/a303-aurora-reference-delivery` | [`de98631c319c`](https://github.com/byungho-cho/roxhistory/tree/de98631c319c7b291a42771f5c755b933542430b) | Historical source preserved; current 279 runtime retained |
| `origin/docs/a303-aurora-release-review` | [`cdcb138a13f5`](https://github.com/byungho-cho/roxhistory/tree/cdcb138a13f5c0cdbfd0f505595e6f6453825766) | Historical source preserved; current 279 runtime retained |
| `origin/docs/a303-flight-clouds-delivery` | [`4ebb87d2a4af`](https://github.com/byungho-cho/roxhistory/tree/4ebb87d2a4af2d5168f6bdcac46301f182d14096) | Historical source preserved; current 279 runtime retained |
| `origin/docs/a303-living-map-delivery` | [`bbe17dc9b529`](https://github.com/byungho-cho/roxhistory/tree/bbe17dc9b52959326abef95e412a648bbbdf41e0) | Historical source preserved; current 279 runtime retained |
| `origin/docs/a303-panel-fade-review` | [`69ae9bdeef8c`](https://github.com/byungho-cho/roxhistory/tree/69ae9bdeef8cc257d463c1349a640b9a4c8b1410) | Historical source preserved; current 279 runtime retained |
| `origin/docs/a303-selection-final-validation` | [`ac0dee3432fd`](https://github.com/byungho-cho/roxhistory/tree/ac0dee3432fdc71f8c59a861bdc32ab8e91fea88) | Historical source preserved; current 279 runtime retained |
| `origin/docs/a303-validation` | [`1a35a7511a4a`](https://github.com/byungho-cho/roxhistory/tree/1a35a7511a4a8fce1b8e3ace193c5a6b55021f19) | Historical source preserved; current 279 runtime retained |
| `origin/docs/current-status-residents-20261103` | [`4e3e16fffe89`](https://github.com/byungho-cho/roxhistory/tree/4e3e16fffe895c7466408d3b364510a01d6d4c9a) | Historical source preserved; current 279 runtime retained |
| `origin/docs/design-handover-v0.1` | [`5ba9398c3620`](https://github.com/byungho-cho/roxhistory/tree/5ba9398c362026b216ba2ee45a38cdbb3a52ebdf) | Historical source preserved; current 279 runtime retained |
| `origin/docs/isometric-release-034` | [`b98e5b9442b6`](https://github.com/byungho-cho/roxhistory/tree/b98e5b9442b6b8d4879e0eafc2b2cc37c30424fd) | Historical source preserved; current 279 runtime retained |
| `origin/docs/leveling-balance-20261110` | [`ba6f5d978c61`](https://github.com/byungho-cho/roxhistory/tree/ba6f5d978c61a4f34e200cb05a351270ef75a6be) | Historical source preserved; current 279 runtime retained |
| `origin/docs/lordrush-local-followup-20261031` | [`570271bfd6f7`](https://github.com/byungho-cho/roxhistory/tree/570271bfd6f737e54a11d9a686432090321217dc) | Historical source preserved; current 279 runtime retained |
| `origin/docs/lordrush-playtest-20261031` | [`5ff5947f7355`](https://github.com/byungho-cho/roxhistory/tree/5ff5947f7355c0885ee63d2f78ae77cbba7ceff2) | Historical source preserved; current 279 runtime retained |
| `origin/docs/lordrush-video-reference` | [`52d3990ef902`](https://github.com/byungho-cho/roxhistory/tree/52d3990ef902530fef77cf391ef219980e5b99aa) | Historical source preserved; current 279 runtime retained |
| `origin/docs/numbered-development-instructions-20261103` | [`c88e9df42563`](https://github.com/byungho-cho/roxhistory/tree/c88e9df42563c00011d13b1a4b284509f589afe7) | Historical source preserved; current 279 runtime retained |
| `origin/docs/play-flow-release-20261103` | [`578c603c3ef2`](https://github.com/byungho-cho/roxhistory/tree/578c603c3ef2e592782564ebe255acac84f9aaa0) | Historical source preserved; current 279 runtime retained |
| `origin/docs/pptx-pdf-sync` | [`1b82ece81243`](https://github.com/byungho-cho/roxhistory/tree/1b82ece812434f7529f1552fbb34b4df2e234659) | Historical source preserved; current 279 runtime retained |
| `origin/docs/presentation-pdf-previews` | [`bdd0782a8c84`](https://github.com/byungho-cho/roxhistory/tree/bdd0782a8c84e6a1634293256db5bde52c3b8a57) | Historical source preserved; current 279 runtime retained |
| `origin/docs/quality-roadmap-v0.1` | [`eb4902ff32f3`](https://github.com/byungho-cho/roxhistory/tree/eb4902ff32f327d592384aabe164e8035e97c664) | Historical source preserved; current 279 runtime retained |
| `origin/docs/quest-sequence-rewards-20261109` | [`dac4783cb9c0`](https://github.com/byungho-cho/roxhistory/tree/dac4783cb9c0a7a5a874c2c74f79157eebc90912) | Historical source preserved; current 279 runtime retained |
| `origin/docs/reincarnation-idea-20261103-0818` | [`4d6edf7cd0e7`](https://github.com/byungho-cho/roxhistory/tree/4d6edf7cd0e731995ce97292dc5fa05baf2fc93d) | Historical source preserved; current 279 runtime retained |
| `origin/docs/release-031-20261104` | [`d8d8fb0560a7`](https://github.com/byungho-cho/roxhistory/tree/d8d8fb0560a783257d602f34e86de57d508be74d) | Historical source preserved; current 279 runtime retained |
| `origin/docs/release-032-20261104` | [`fdb3ff359dc9`](https://github.com/byungho-cho/roxhistory/tree/fdb3ff359dc9cd2e25e322ba15abceddfa8f757b) | Historical source preserved; current 279 runtime retained |
| `origin/docs/release-036-validation` | [`a9b0cff29446`](https://github.com/byungho-cho/roxhistory/tree/a9b0cff294463e2e0eddd5953e5bf682feaff5bd) | Historical source preserved; current 279 runtime retained |
| `origin/docs/release-v030-verified` | [`d32537ca05f1`](https://github.com/byungho-cho/roxhistory/tree/d32537ca05f1d30b9bb0824560fd8d26bf558d37) | Historical source preserved; current 279 runtime retained |
| `origin/docs/s40000-final-v022` | [`ee860686bbab`](https://github.com/byungho-cho/roxhistory/tree/ee860686bbab5ab5622611096ee8881a84e07bf5) | Historical source preserved; current 279 runtime retained |
| `origin/docs/s40000-release-20261103` | [`edc8218b81ca`](https://github.com/byungho-cho/roxhistory/tree/edc8218b81cab7ddde107a927afa8ef292063504) | Historical source preserved; current 279 runtime retained |
| `origin/docs/team-lead-notes-20261102` | [`11c9bdb236d8`](https://github.com/byungho-cho/roxhistory/tree/11c9bdb236d83cbbc3aa2abaa94ac3cee8bfb6e8) | Historical source preserved; current 279 runtime retained |
| `origin/docs/visual-refactor-reference-20261031` | [`9502cf9df320`](https://github.com/byungho-cho/roxhistory/tree/9502cf9df320d032ca20252eda297377bbfa55c6) | Historical source preserved; current 279 runtime retained |
| `origin/docs/walk-residents-verification` | [`7b3ea21648e1`](https://github.com/byungho-cho/roxhistory/tree/7b3ea21648e1cf88b0d3f522b7a783880699260a) | Historical source preserved; current 279 runtime retained |
| `origin/docs/windows-033-20261104` | [`9c0312a2435d`](https://github.com/byungho-cho/roxhistory/tree/9c0312a2435dbd0b23de4a83a5ccdfdf2ecdc3de) | Historical source preserved; current 279 runtime retained |
| `origin/docs/worldlife-verification-20261103` | [`e6305b00e1cd`](https://github.com/byungho-cho/roxhistory/tree/e6305b00e1cd486f4237e95a3a45dc7283990dac) | Historical source preserved; current 279 runtime retained |
| `origin/exp/hybrid-3d-character` | [`0d297768fb26`](https://github.com/byungho-cho/roxhistory/tree/0d297768fb260347f45c22da1150de22c6139981) | Historical source preserved; current 279 runtime retained |
| `origin/feat/a303-art-fidelity` | [`bbdbcd151153`](https://github.com/byungho-cho/roxhistory/tree/bbdbcd1511537e295ee50aac1db7ae8cecf4ee60) | Historical source preserved; current 279 runtime retained |
| `origin/feat/a303-aurora-icon` | [`0e9b67695e1b`](https://github.com/byungho-cho/roxhistory/tree/0e9b67695e1b1d4e309a22fe28b371921474d6f7) | Historical source preserved; current 279 runtime retained |
| `origin/feat/a303-fixed-selection` | [`25753e917370`](https://github.com/byungho-cho/roxhistory/tree/25753e9173705888359d36f313b879a78f5bfad5) | Historical source preserved; current 279 runtime retained |
| `origin/feat/a303-living-map-effects` | [`ccb6ed6a6e67`](https://github.com/byungho-cho/roxhistory/tree/ccb6ed6a6e67c360d1736622b4f433d1dbe434fa) | Historical source preserved; current 279 runtime retained |
| `origin/feat/action-queue-brush-20261104` | [`95bd13bb2c83`](https://github.com/byungho-cho/roxhistory/tree/95bd13bb2c83fab8598d5ccaff95cb501d7ce646) | Historical source preserved; current 279 runtime retained |
| `origin/feat/apk-motion-boundary-20261104` | [`45fb50f3157d`](https://github.com/byungho-cho/roxhistory/tree/45fb50f3157dfbc6ce435c0bae9855fb0a3f64f7) | Historical source preserved; current 279 runtime retained |
| `origin/feat/build-preview-fold-menu-20261104` | [`d4f93a0d77e6`](https://github.com/byungho-cho/roxhistory/tree/d4f93a0d77e67964c328f4e2784ed8fa52820e4a) | Historical source preserved; current 279 runtime retained |
| `origin/feat/c001-character-ui-v019` | [`ca0b5fbf74a2`](https://github.com/byungho-cho/roxhistory/tree/ca0b5fbf74a252bf80815758e0a9f11ba7ef77b6) | Historical source preserved; current 279 runtime retained |
| `origin/feat/figma-visual-parity-20261105` | [`18246742e89a`](https://github.com/byungho-cho/roxhistory/tree/18246742e89a4c558cbe994e947b3efcd2d5e76d) | Historical source preserved; current 279 runtime retained |
| `origin/feat/hero-quality-pass` | [`5f5fd40532d0`](https://github.com/byungho-cho/roxhistory/tree/5f5fd40532d0f0173047701d8bb851e04fd20960) | Historical source preserved; current 279 runtime retained |
| `origin/feat/isometric-village-20261105` | [`fd563ffa009d`](https://github.com/byungho-cho/roxhistory/tree/fd563ffa009dfa4a071249f7583fad6909126e84) | Historical source preserved; current 279 runtime retained |
| `origin/feat/meshy-region-selection-v0110` | [`32172667df52`](https://github.com/byungho-cho/roxhistory/tree/32172667df52fcb89543584f3e34109c6b302f56) | Historical source preserved; current 279 runtime retained |
| `origin/feat/movement-v057-20261107` | [`f22032cff26a`](https://github.com/byungho-cho/roxhistory/tree/f22032cff26a79fdd2d9e53c1af566c62aaeb375) | Historical source preserved; current 279 runtime retained |
| `origin/feat/p2-polish-p3-feedback` | [`8c7e7cbb892c`](https://github.com/byungho-cho/roxhistory/tree/8c7e7cbb892ce5c14096ad588364e853c5510c8f) | Historical source preserved; current 279 runtime retained |
| `origin/feat/play-experience-v017` | [`c6d21ac5c5c0`](https://github.com/byungho-cho/roxhistory/tree/c6d21ac5c5c0c08cd2873ef5842bb9b0f536f697) | Historical source preserved; current 279 runtime retained |
| `origin/feat/play-flow-20261103` | [`efafc60ef6e6`](https://github.com/byungho-cho/roxhistory/tree/efafc60ef6e6f8a47072a786d50935ce4e9eef8a) | Historical source preserved; current 279 runtime retained |
| `origin/feat/play-interaction-polish` | [`d7b16d66b3b7`](https://github.com/byungho-cho/roxhistory/tree/d7b16d66b3b7d561b4b18223a58aa7ecfde4adaa) | Historical source preserved; current 279 runtime retained |
| `origin/feat/s40000-faithful-world-20261103` | [`5bca6962a0b5`](https://github.com/byungho-cho/roxhistory/tree/5bca6962a0b54104853751d505011d22c061e969) | Historical source preserved; current 279 runtime retained |
| `origin/feat/s40000-world-life-20261103` | [`4fe66ec2826a`](https://github.com/byungho-cho/roxhistory/tree/4fe66ec2826a5a1b83f9b85ed3b78284db084814) | Historical source preserved; current 279 runtime retained |
| `origin/feat/selected-hud-build-sites-20261104` | [`2586169bfb91`](https://github.com/byungho-cho/roxhistory/tree/2586169bfb91abe190d526a4e6954b34807ff25f) | Historical source preserved; current 279 runtime retained |
| `origin/feat/stage2-characters-short-demo` | [`d4fafb1b6b54`](https://github.com/byungho-cho/roxhistory/tree/d4fafb1b6b542e573a7b837127525057a112c052) | Historical source preserved; current 279 runtime retained |
| `origin/feat/stage4-ui-camera-sound` | [`bc20b8ca333b`](https://github.com/byungho-cho/roxhistory/tree/bc20b8ca333bd1583a25df64802886b7f5e219a1) | Historical source preserved; current 279 runtime retained |
| `origin/feat/village-controls-polish` | [`4bfc341ee8d5`](https://github.com/byungho-cho/roxhistory/tree/4bfc341ee8d53eca18c7430b58fc091d823c4e06) | Historical source preserved; current 279 runtime retained |
| `origin/feat/visual-refactor-v018` | [`069b25c1bab2`](https://github.com/byungho-cho/roxhistory/tree/069b25c1bab239055f3aa9d17916fa941dd9b9ec) | Historical source preserved; current 279 runtime retained |
| `origin/feat/walk-residents-audio` | [`8bcb9c59759d`](https://github.com/byungho-cho/roxhistory/tree/8bcb9c59759daec1c5593081d7d52c1d8b440f23) | Historical source preserved; current 279 runtime retained |
| `origin/feat/windows-review-20261107` | [`430faa852662`](https://github.com/byungho-cho/roxhistory/tree/430faa852662a1db4143321eef889882b3c498ed) | Historical source preserved; current 279 runtime retained |
| `origin/fix/a303-aurora-reference` | [`15945eec70a7`](https://github.com/byungho-cho/roxhistory/tree/15945eec70a7d9cb156591e57f66be5c79bfa3de) | Historical source preserved; current 279 runtime retained |
| `origin/fix/a303-flight-label-clouds` | [`e2d5359e2684`](https://github.com/byungho-cho/roxhistory/tree/e2d5359e2684e7a637e7a964a2b926b3fe900af5) | Historical source preserved; current 279 runtime retained |
| `origin/fix/a303-panel-ghosting` | [`7a9b9713fbce`](https://github.com/byungho-cho/roxhistory/tree/7a9b9713fbce259f9c28b896132265701be03e1a) | Historical source preserved; current 279 runtime retained |
| `origin/fix/roxhistory-ui-review-20261105` | [`e6e24bfb8ee0`](https://github.com/byungho-cho/roxhistory/tree/e6e24bfb8ee0b68ef9b6f57a13d9852b0ddeaae0) | Historical source preserved; current 279 runtime retained |
| `origin/fix/s40000-ci-render-budget` | [`f2aedb05412f`](https://github.com/byungho-cho/roxhistory/tree/f2aedb05412f1560b1d8d90659c49b4e9093afdb) | Historical source preserved; current 279 runtime retained |
| `origin/fix/s40000-figma-controls` | [`6342aee5b624`](https://github.com/byungho-cho/roxhistory/tree/6342aee5b624c453932a95a2cc622ddcce5937a7) | Historical source preserved; current 279 runtime retained |
| `origin/fix/settlement-depth` | [`be5c4b0fc131`](https://github.com/byungho-cho/roxhistory/tree/be5c4b0fc131e42031713edf79f6a018843e3c2c) | Historical source preserved; current 279 runtime retained |
| `origin/share/asset-plan-v007` | [`bdd61b093744`](https://github.com/byungho-cho/roxhistory/tree/bdd61b09374487961b3eeef5d419baa29ee7e01e) | Historical source preserved; current 279 runtime retained |
| `origin/share/reference-assets` | [`1699a46e2775`](https://github.com/byungho-cho/roxhistory/tree/1699a46e2775e5923509e2130a6e5dad11db2919) | Historical source preserved; current 279 runtime retained |
