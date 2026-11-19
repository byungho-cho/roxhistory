# D0061 R08 preflight — unreleased candidate

User explicitly confirmed R08 and excluded resource-download architecture separation. This supersedes the earlier separate-motion scope: REQ-042 final approved clips are now required before combined publication.

- Preserve design's existing uncommitted REQ-040 integration; measured B triangle counts/SHA-256 match the shared results for all four species. No hunt model replacement.
- Z90000 common ally buttons: guard caption is 가드; unsupported guard/counter/death remain disabled. No dedicated thrust/short-sling/dodge buttons. Only the Z90000 Hangyeol playlist excludes stone_spear_thrust, via a preview-specific filter; source clips and actual hunt mappings stay intact.
- R08 final approved REQ-042 motion files have not been found in the delivery folder. RES-043 and its review explicitly identify C as first-pass running candidates and jump/sling/hit reform as incomplete. Do not silently publish those candidates as final.
- Reserve 0.2.260 for a local packaging candidate to measure the 800,000,000-byte cap and compare package/signer with 0.2.259. This is not a final/released APK until required motion integration and validation are complete; any source change requires rebuilding.
- ADB device list is empty; no emulator/system image is installed. Static package/signer compatibility and save tests must be distinguished from an actual Android in-place install test.
- Continue to use existing build/publish scripts and signing material; no download-architecture split, save reset, key replacement or monitoring activation.

Conditional release remains held until the missing approved motion inputs and required verification are satisfied. Existing 0.2.259 distribution remains usable.
