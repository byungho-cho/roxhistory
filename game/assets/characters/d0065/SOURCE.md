# D0065 deployment selection

Han's deployed scene is the unchanged D0061 candidate, 11,979 triangles:
`../d0061/hangyeol-B-12k.glb`, SHA256
`f77365e7c65161d62024e9ef06f074b47e22a55ff3c8bced3b58c5d78726d26e`.
Drive source: `14XpbahyidRfkBsLL8NI4P-T_hSNylyHS`.

It already contains R03 jump spear and approved spear guard clips. The rest
matrices match the former high-poly scenes exactly. Forty-one samples per
inherited track were checked against d0057 and the separate d0055 jump scene;
maximum quaternion component metric is below 0.000005, positions/scales match.
No extra high-poly scene is required to load these clips.

Both export presets exclude d0051/hangyeol-combat, d0055, d0056/hangyeol-lab-req031
and d0057/hangyeol-req035 source/texture resources. These original files remain in source control; the low model's
shared texture content remains available under d0061. Past APKs are not shrunk
by a PCK overlay. The same exclusion rules apply to the next full build.

Normal resident previews replace only the `run` Animation in an instance-local
library with D0064 C, keeping mesh, rig, materials, equipment and other clips.
The separate A/B/C adapter keeps its explicit former A and native B clocks,
now using the same low-poly Han mesh in all three columns.

Playback multipliers belong to motion_timing.gd and are applied once. Preview
path velocity stays independent of the shortened walk period. Live R03 jump
uses the same 2x visual rate with a delayed preparation hold, preserving the
existing 94/60-second hit event and 3.2-second action lock; no combat rules or
audio/VFX event timestamps are moved.
