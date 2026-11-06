# 0.1.46: approved outpost stages

Outpost level 2/3/4 upgrades are now enabled using the user-approved files from share/reference-assets commit b046bf0f491290a42e4a0f67b22b6e336a829d14, assets/buildings/outposts/v002. Local sources: game/assets/outposts-v002. All three original PNG byte hashes match the supplied manifest; source pixels are unchanged.

Catalog entries BLD-OUTPOST-L2/L3/L4 use padded atlas windows, stage-specific ground pivots and ground-span scaling. Visible ground span is 180 world units; the common pivot lands at building origin plus (0,3). Roof size does not alter collision. Stage 1 rendering is unchanged. Original transparent margins remain in source files; metadata controls placement. Structural wood platforms/stairs remain part of the sprites, while the shared stage foundation is drawn once separately. No terrain background was added to building sprites.

Exact raw-image ground pivots: L2 (710,800), L3 (720,880), L4 (710,800). Ground spans: 780/790/830 source pixels. These are rendering calibration values checked against actual game captures, not measurements that alter gameplay footprints.

Costs remain 20 wood + 20 stone per upgrade, durations 4/8/16 seconds. Initial outpost construction remains 15/10. Existing confirmation, animated hammer/progress, offline completion, stable IDs and save validation are reused. No save migration/reset, coordinate change or collision change.

Validation: 32 new outpost integration checks, 53 durable owned-upgrade checks and 20 chief-workflow checks pass (105 total). Confirmed actual UI starts all three stages, correct cost, progress anchoring, stage texture, pivot/width, unchanged collision and save reload. Desktop maximum-zoom captures for levels 2/3/4 reviewed: foundations align and no duplicate earth background is visible. Assets remain AI-assisted approved separations; fine color fringes can be visible at source resolution. Physical Android testing not performed.

All 0.1.45 changes retained. Village capacity expansion remains a proposal only; upgrade mixed sound remains pending approval. No main merge.
