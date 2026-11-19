# D0066 · REQ046 lightweight motion profile

Retained D0061 lightweight mesh scenes are used as deployed models. The supplied
REQ046 scenes match their bone rest matrices and triangle counts exactly. Only
Animation resources are extracted, including unchanged reference walk/run/hit
curves to avoid the earlier scene importer's small key-reduction differences.

| Source | Drive ID | Triangles | SHA256 |
| --- | --- | --- | --- |
| forest-deer-req046 | 1mBNzMbco2aEHzYIXuweBEVKo7FCvT7zY | 10,000 | 091e2eb7e8f8f0708ade935b5d7a8764086a458e81e9c750ff9480c9976dc578 |
| mountain-stag-req046 | 1G141BOUye2pAtD1Lm5BeIhfISDvXpLKc | 10,000 | ef666d0d750a2cd017ed939e2f577fd51c8197f12541a2ed2bbdaf92d029e7fd |
| juvenile-boar-req046 | 1jHJuV4tGmYcAIqdvRfVJ1DEp4j8GYvO1 | 9,998 | 0da7953ed5696943154e25eee0bbaf99adfa24378015bf25df9950d3e1e354de |
| adult-boar-req046 | 11j_yFZsMh1qwPCzzgxqPb_Kts5ApVx4C | 11,998 | 721202b21d27e80805b9cacd900f740d11fc40fe6c2c7a5f60cd39b9d57957cc |

`model_motion_profile.gd` follows the supplied REQ046 rate and skill section
tables: walk deer 1.5x / boar 1.75x; run 1.25x; skill anticipation 1x and
execute 2x. Contact markers are visual only. Common deaths play once, hold
0.6 seconds after the authored fall, then fade over 0.6 seconds. Boss death
uses its dedicated clip and holds the final pose. Restart restores opacity.

Z90000 uses this profile. The separate legacy wildlife lab also reuses the
lightweight meshes but preserves its existing motion controls and timing.
Consequently no runtime path references d0059 high-poly scenes; export presets
exclude that directory while the original production sources remain in Git.
