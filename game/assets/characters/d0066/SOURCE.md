# D0066 · motion-only additions

Approved base meshes remain Uram RES009 (11,839 triangles), Han D0061 (11,979)
and Sae REQ035 (9,997). REQ045 and REQ047 branched independently from these
rigs; only their prefixed Animation resources are merged into private libraries.
No GLB, replacement rig, texture, material or high-poly comparison model is added.

| Input | Drive file ID | SHA256 |
| --- | --- | --- |
| Uram REQ045 | 1uq7FV3JJhJAKVw6fAWH_ncJrPhhOJK_z | 8ecf04e3743e4bfd621cf0c9004805e3b17d10a2e345a3871355aa5f4bd6d25e |
| Han REQ045 | 1sY9e6uhNKCDO7_L_ZroZUfq41do7gG5a | 9394d062160d95aa0e322aa4b2e1f389b3d5e4877ad6192fc1f291aa77e246d1 |
| Sae REQ045 | 1wjulyX-lDP20BwDpejMMBODalbpr9E2o | d5c4d8bdcbeaf85bda7eab0ff0fb5017a633df59a9dc6a02877c436e246037b1 |
| Uram REQ047 | 1uNUsKacOl2Reg7Pcb-SAROYvl4BgTLie | 397dcdf200e3851e4ec895329d7c180d0a4cd2f5863a49dfaf009792bd27a30c |
| Han REQ047 | 1KjTEz9uRDmNL-6xIGK352So5MXVKaH8D | 348299b73775d70357c740a96e0d1f6f1fe35d8cbd79e0062b6ea57f2b62ce6d |
| Sae REQ047 | 1KSo9sQpBD2V0-eMKtgY00d8X_IClLwsn | 1b5f3d6b99024f7d8a6cb1b07ab2288684e0c077d6a726795256d8fffb7616fe |

New clips retain their native timing. Existing D0065 multipliers and C run clips
are preserved. The Z90000 profile alone maps general/linked skills and new
guard/counter/death actions; existing combat event callers are not redirected.
In ALL, linked preview starts Uram parry, then Sae support, then Han jump.
Sae's authored palm direction is calibrated at transfer time 0.78 seconds and
aimed at Han's visible chest using the current camera projection. No sound,
buff effect, hit test, AI rule, skill point or parry window is introduced.

Exported motion paths are retargeted to each retained scene's Skeleton3D.
Rest matrices and native sampled global bone poses are checked against sources.
