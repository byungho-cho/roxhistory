# RoxHistory runtime asset cleanup

Base: 0.2.312 (5198756). Scope: tracked res://assets only; no build, Figma, original art-source, other worktree, or shared-folder changes.

Scanned 1435 standalone assets against 551 source/data/test/tool files (path, filename, UID and dynamic path families), plus native Godot dependencies. Protected 44 candidates after the engine resolved native model/texture references. Reconciled retained runtime references against the unmerged previous hunt cleanup: only the superseded sound routes and unused preloaded ring art were detached. Uncertain assets were removed in this reversible Git worktree for smoke testing.

Restore individual archived assets from the parent of the cleanup commit, including the matching .import/.uid sidecar and any linked scene/model dependencies. They are not deleted from Git history.

## Deleted assets

| File | Source bytes | Evidence |
| --- | ---: | --- |
| game/assets/animals/bear_Image_0.jpg | 78632 | No source or active engine dependency found |
| game/assets/animals/bear_Image_1.jpg | 29857 | No source or active engine dependency found |
| game/assets/animals/bear_Image_2.jpg | 28079 | No source or active engine dependency found |
| game/assets/animals/bear.glb | 783576 | No source or active engine dependency found |
| game/assets/animals/d0061/adult-boar-B_adult-brown-albedo.png | 4277743 | No source or active engine dependency found |
| game/assets/animals/d0061/adult-boar-B_Image_1.jpg | 1409450 | No source or active engine dependency found |
| game/assets/animals/d0061/adult-boar-B_Image_2.jpg | 1482017 | No source or active engine dependency found |
| game/assets/animals/d0061/adult-boar-B.glb | 8077120 | No source or active engine dependency found |
| game/assets/animals/d0061/forest-deer-B_Image_0.jpg | 2972092 | No source or active engine dependency found |
| game/assets/animals/d0061/forest-deer-B_Image_1.jpg | 1134016 | No source or active engine dependency found |
| game/assets/animals/d0061/forest-deer-B_Image_2.jpg | 1940465 | No source or active engine dependency found |
| game/assets/animals/d0061/forest-deer-B.glb | 6815280 | No source or active engine dependency found |
| game/assets/animals/d0061/juvenile-boar-B_Image_1.jpg | 1409450 | No source or active engine dependency found |
| game/assets/animals/d0061/juvenile-boar-B_Image_2.jpg | 1482017 | No source or active engine dependency found |
| game/assets/animals/d0061/juvenile-boar-B_juvenile-golden-albedo.png | 5166979 | No source or active engine dependency found |
| game/assets/animals/d0061/juvenile-boar-B.glb | 8834280 | No source or active engine dependency found |
| game/assets/animals/d0061/mountain-stag-B_Image_0.jpg | 2972092 | No source or active engine dependency found |
| game/assets/animals/d0061/mountain-stag-B_Image_1.jpg | 1134016 | No source or active engine dependency found |
| game/assets/animals/d0061/mountain-stag-B_Image_2.jpg | 1940465 | No source or active engine dependency found |
| game/assets/animals/d0061/mountain-stag-B.glb | 6897560 | No source or active engine dependency found |
| game/assets/animals/deer_Image_0.jpg | 132554 | No source or active engine dependency found |
| game/assets/animals/deer_Image_1.jpg | 37737 | No source or active engine dependency found |
| game/assets/animals/deer_Image_2.jpg | 32928 | No source or active engine dependency found |
| game/assets/animals/deer.glb | 785268 | No source or active engine dependency found |
| game/assets/animals/rabbit_Image_0.jpg | 96065 | No source or active engine dependency found |
| game/assets/animals/rabbit_Image_1.jpg | 34630 | No source or active engine dependency found |
| game/assets/animals/rabbit_Image_2.jpg | 25883 | No source or active engine dependency found |
| game/assets/animals/rabbit.glb | 754184 | No source or active engine dependency found |
| game/assets/app-icon-hut.png | 13982 | No source or active engine dependency found |
| game/assets/audio/complete.wav | 51200 | No source or active engine dependency found |
| game/assets/audio/d0001-approved/action-click.wav | 13484 | No source or active engine dependency found |
| game/assets/audio/d0004-approved/heavy-hit.wav | 352878 | Retired hunt asset; prior cleanup reviewed |
| game/assets/audio/d0004-approved/popup-close.wav | 176478 | Retired hunt asset; prior cleanup reviewed |
| game/assets/audio/d0004-approved/victory.wav | 529278 | Retired hunt asset; prior cleanup reviewed |
| game/assets/audio/d0069/intro-bgm.wav | 5513260 | No source or active engine dependency found |
| game/assets/audio/hunt-d0003/B01.wav | 6773804 | Retired hunt asset; prior cleanup reviewed |
| game/assets/audio/hunt-d0003/B02.wav | 2116844 | Retired hunt asset; prior cleanup reviewed |
| game/assets/audio/hunt-d0003/B03.wav | 6773804 | Retired hunt asset; prior cleanup reviewed |
| game/assets/audio/hunt-d0003/S01.wav | 13274 | Retired hunt asset; prior cleanup reviewed |
| game/assets/audio/hunt-d0003/S02.wav | 30912 | Retired hunt asset; prior cleanup reviewed |
| game/assets/audio/hunt-d0003/S03.wav | 14156 | Retired hunt asset; prior cleanup reviewed |
| game/assets/audio/hunt-d0003/S04.wav | 44144 | Retired hunt asset; prior cleanup reviewed |
| game/assets/audio/hunt-d0003/S05.wav | 30912 | Retired hunt asset; prior cleanup reviewed |
| game/assets/audio/hunt-d0003/S06.wav | 22094 | Retired hunt asset; prior cleanup reviewed |
| game/assets/audio/hunt-d0003/S07.wav | 22094 | Retired hunt asset; prior cleanup reviewed |
| game/assets/audio/hunt-d0003/S08.wav | 17684 | Retired hunt asset; prior cleanup reviewed |
| game/assets/audio/hunt-d0003/S09.wav | 44144 | Retired hunt asset; prior cleanup reviewed |
| game/assets/audio/hunt-d0003/S10.wav | 35324 | Retired hunt asset; prior cleanup reviewed |
| game/assets/audio/hunt-d0003/S11.wav | 70604 | Retired hunt asset; prior cleanup reviewed |
| game/assets/audio/hunt-d0003/S12.wav | 88244 | Retired hunt asset; prior cleanup reviewed |
| game/assets/audio/hunt-d0003/S13.wav | 16802 | Retired hunt asset; prior cleanup reviewed |
| game/assets/audio/hunt-d0003/S14.wav | 24740 | Retired hunt asset; prior cleanup reviewed |
| game/assets/audio/hunt-d0003/S15.wav | 19448 | Retired hunt asset; prior cleanup reviewed |
| game/assets/audio/hunt-d0003/S16.wav | 28268 | Retired hunt asset; prior cleanup reviewed |
| game/assets/audio/hunt-d0003/S17.wav | 44144 | Retired hunt asset; prior cleanup reviewed |
| game/assets/audio/hunt-d0003/S18.wav | 79424 | Retired hunt asset; prior cleanup reviewed |
| game/assets/audio/hunt-d0003/S19.wav | 70604 | Retired hunt asset; prior cleanup reviewed |
| game/assets/audio/hunt-d0003/S20.wav | 75014 | Retired hunt asset; prior cleanup reviewed |
| game/assets/audio/hunt-d0003/S22.wav | 35324 | Retired hunt asset; prior cleanup reviewed |
| game/assets/audio/hunt-d0003/S23.wav | 66194 | Retired hunt asset; prior cleanup reviewed |
| game/assets/audio/hunt-d0003/S24.wav | 57374 | Retired hunt asset; prior cleanup reviewed |
| game/assets/audio/hunt-d0003/S26.wav | 176444 | Retired hunt asset; prior cleanup reviewed |
| game/assets/audio/hunt-d0003/S27.wav | 158804 | Retired hunt asset; prior cleanup reviewed |
| game/assets/audio/hunt-d0003/S28.wav | 79424 | Retired hunt asset; prior cleanup reviewed |
| game/assets/audio/intro-d0004/05_Direct_Era_Rise_Story_End_Smooth_v2_35s.mp3 | 841580 | No source or active engine dependency found |
| game/assets/audio/intro-d0004/07_Runway_Opening_Ending_35s.mp3 | 841394 | No source or active engine dependency found |
| game/assets/audio/reward.wav | 47672 | No source or active engine dependency found |
| game/assets/audio/village-sfx-v02/construction-work-v02.wav | 176478 | No source or active engine dependency found |
| game/assets/audio/wind.wav | 1058444 | No source or active engine dependency found |
| game/assets/buildings-review-v001/outpost-level1.png | 997408 | No source or active engine dependency found |
| game/assets/buildings/approved-v001/training/training-l1-structure.png | 348006 | No source or active engine dependency found |
| game/assets/buildings/approved-v001/training/training-l2-structure.png | 1427753 | No source or active engine dependency found |
| game/assets/buildings/approved-v001/training/training-l3-structure.png | 551696 | No source or active engine dependency found |
| game/assets/buildings/approved-v001/training/training-l4-structure.png | 1261386 | No source or active engine dependency found |
| game/assets/buildings/storage-v001/stone_store-l1.png | 2431222 | No source or active engine dependency found |
| game/assets/buildings/storage-v001/stone_store-l2.png | 2215413 | No source or active engine dependency found |
| game/assets/buildings/storage-v001/stone_store-l3.png | 1610710 | No source or active engine dependency found |
| game/assets/buildings/storage-v001/stone_store-l4.png | 2375484 | No source or active engine dependency found |
| game/assets/buildings/storage-v001/wood_store-l1.png | 2371380 | No source or active engine dependency found |
| game/assets/buildings/storage-v001/wood_store-l2.png | 1647954 | No source or active engine dependency found |
| game/assets/buildings/storage-v001/wood_store-l3.png | 1904388 | No source or active engine dependency found |
| game/assets/buildings/storage-v001/wood_store-l4.png | 1730294 | No source or active engine dependency found |
| game/assets/characters/d0047/uram-B-rigged_Image_0.png | 519345 | No source or active engine dependency found |
| game/assets/characters/d0047/uram-B-rigged_Image_1.png | 260614 | No source or active engine dependency found |
| game/assets/characters/d0047/uram-B-rigged_Image_2.png | 349182 | No source or active engine dependency found |
| game/assets/characters/d0047/uram-B-rigged.glb | 2066720 | No source or active engine dependency found |
| game/assets/characters/d0051/hangyeol-combat_Image_0.jpg | 3350491 | No source or active engine dependency found |
| game/assets/characters/d0051/hangyeol-combat_Image_1.jpg | 1510137 | No source or active engine dependency found |
| game/assets/characters/d0051/hangyeol-combat_Image_2.jpg | 2418404 | No source or active engine dependency found |
| game/assets/characters/d0051/hangyeol-combat.glb | 9934284 | No source or active engine dependency found |
| game/assets/characters/d0051/saebom-combat_Image_0.jpg | 3312368 | No source or active engine dependency found |
| game/assets/characters/d0051/saebom-combat_Image_1.jpg | 1859952 | No source or active engine dependency found |
| game/assets/characters/d0051/saebom-combat_Image_2.jpg | 2416736 | No source or active engine dependency found |
| game/assets/characters/d0051/saebom-combat.glb | 8272884 | No source or active engine dependency found |
| game/assets/characters/d0055/hangyeol-auto-r03_Image_0.jpg | 3350491 | No source or active engine dependency found |
| game/assets/characters/d0055/hangyeol-auto-r03_Image_1.jpg | 1510137 | No source or active engine dependency found |
| game/assets/characters/d0055/hangyeol-auto-r03_Image_2.jpg | 2418404 | No source or active engine dependency found |
| game/assets/characters/d0055/hangyeol-auto-r03.glb | 10358800 | No source or active engine dependency found |
| game/assets/characters/d0056/hangyeol-lab-req031_Image_0.jpg | 3350491 | No source or active engine dependency found |
| game/assets/characters/d0056/hangyeol-lab-req031_Image_1.jpg | 1510137 | No source or active engine dependency found |
| game/assets/characters/d0056/hangyeol-lab-req031_Image_2.jpg | 2418404 | No source or active engine dependency found |
| game/assets/characters/d0056/hangyeol-lab-req031.glb | 10421024 | No source or active engine dependency found |
| game/assets/characters/d0056/saebom-req028_Image_0.jpg | 3312368 | No source or active engine dependency found |
| game/assets/characters/d0056/saebom-req028_Image_1.jpg | 1859952 | No source or active engine dependency found |
| game/assets/characters/d0056/saebom-req028_Image_2.jpg | 2416736 | No source or active engine dependency found |
| game/assets/characters/d0056/saebom-req028.glb | 8949420 | No source or active engine dependency found |
| game/assets/characters/d0061/hangyeol-B-12k_Image_0.jpg | 3350491 | No source or active engine dependency found |
| game/assets/characters/d0061/hangyeol-B-12k_Image_1.jpg | 1510137 | No source or active engine dependency found |
| game/assets/characters/d0061/hangyeol-B-12k_Image_2.jpg | 2418404 | No source or active engine dependency found |
| game/assets/characters/d0061/hangyeol-B-12k.glb | 8455348 | No source or active engine dependency found |
| game/assets/characters/residents-v5/figma-residents-source.png | 531945 | No source or active engine dependency found |
| game/assets/farm/v002/farm-l1.png | 163413 | No source or active engine dependency found |
| game/assets/farm/v002/farm-l2.png | 199456 | No source or active engine dependency found |
| game/assets/farm/v002/farm-l3.png | 243006 | No source or active engine dependency found |
| game/assets/farm/v002/farm-l4.png | 325662 | No source or active engine dependency found |
| game/assets/farm/v002/menu-farm-locked.png | 50776 | No source or active engine dependency found |
| game/assets/farm/v002/menu-farm-normal.png | 50188 | No source or active engine dependency found |
| game/assets/figma/02422.svg | 2989 | No source or active engine dependency found |
| game/assets/figma/0e5b8.png | 3372796 | No source or active engine dependency found |
| game/assets/figma/0fa22.svg | 518 | No source or active engine dependency found |
| game/assets/figma/2a735.svg | 2414 | No source or active engine dependency found |
| game/assets/figma/4c704.svg | 2880 | No source or active engine dependency found |
| game/assets/figma/75484.svg | 841 | No source or active engine dependency found |
| game/assets/figma/ba95c.svg | 10930 | No source or active engine dependency found |
| game/assets/figma/d3b84.svg | 510 | No source or active engine dependency found |
| game/assets/figma/f1627.svg | 1614 | No source or active engine dependency found |
| game/assets/figma/fac42.svg | 1596 | No source or active engine dependency found |
| game/assets/figma/fbe0a.svg | 422 | No source or active engine dependency found |
| game/assets/foundations-v001/level-1.png | 1369062 | No source or active engine dependency found |
| game/assets/foundations-v001/level-2.png | 1611830 | No source or active engine dependency found |
| game/assets/foundations-v001/level-3.png | 1865046 | No source or active engine dependency found |
| game/assets/foundations-v001/level-4.png | 1826507 | No source or active engine dependency found |
| game/assets/icon.svg | 571 | No source or active engine dependency found |
| game/assets/outposts-v002/outpost-level2.png | 1251079 | No source or active engine dependency found |
| game/assets/outposts-v002/outpost-level3.png | 1217066 | No source or active engine dependency found |
| game/assets/outposts-v002/outpost-level4.png | 1435133 | No source or active engine dependency found |
| game/assets/placeholders/farm.svg | 370 | No source or active engine dependency found |
| game/assets/quest-rewards/panel.png | 3098989 | No source or active engine dependency found |
| game/assets/quest-rewards/parts.png | 1456094 | No source or active engine dependency found |
| game/assets/refactor-v036/watchtower.png | 983779 | No source or active engine dependency found |
| game/assets/region-selection/10e90.svg | 395 | No source or active engine dependency found |
| game/assets/region-selection/159ba.svg | 451 | No source or active engine dependency found |
| game/assets/region-selection/2f8a0.png | 2118946 | No source or active engine dependency found |
| game/assets/region-selection/663c6.png | 1694678 | No source or active engine dependency found |
| game/assets/region-selection/8b5a2.svg | 720 | No source or active engine dependency found |
| game/assets/region-selection/8f28a.png | 1627589 | No source or active engine dependency found |
| game/assets/region-selection/90ccd.svg | 395 | No source or active engine dependency found |
| game/assets/region-selection/a211f.svg | 398 | No source or active engine dependency found |
| game/assets/region-selection/ba95c.svg | 10930 | No source or active engine dependency found |
| game/assets/region-selection/fac42.svg | 1600 | No source or active engine dependency found |
| game/assets/region-selection/fc6ce.svg | 720 | No source or active engine dependency found |
| game/assets/terrain-review-v001/village-option2-expanded.png | 2231251 | No source or active engine dependency found |
| game/assets/ui/hunt-impact/team-ally-ellipse.svg | 338 | Retired hunt asset; prior cleanup reviewed |
| game/assets/ui/hunt-impact/team-opponent-ellipse.svg | 337 | Retired hunt asset; prior cleanup reviewed |
| game/assets/ui/hunting-combat/png/common/hp-portrait-deer.png | 16670 | Retired hunt asset; prior cleanup reviewed |
| game/assets/ui/hunting-combat/png/popup/panel.png | 484654 | Retired hunt asset; prior cleanup reviewed |
| game/assets/ui/hunting-combat/png/preparation/quick-sortie-background.png | 44163 | Retired hunt asset; prior cleanup reviewed |
| game/assets/ui/hunting-combat/png/preparation/start-battle-background.png | 84636 | Retired hunt asset; prior cleanup reviewed |
| game/assets/ui/hunting-combat/png/skills/cooperation-background.png | 298651 | Retired hunt asset; prior cleanup reviewed |
| game/assets/ui/hunting-combat/png/skills/cooperation-disabled.png | 248953 | Retired hunt asset; prior cleanup reviewed |
| game/assets/ui/hunting-combat/png/skills/cooperation-icon.png | 118221 | Retired hunt asset; prior cleanup reviewed |
| game/assets/ui/hunting-combat/png/skills/strike-background.png | 275517 | Retired hunt asset; prior cleanup reviewed |
| game/assets/ui/hunting-combat/png/skills/strike-disabled.png | 235152 | Retired hunt asset; prior cleanup reviewed |
| game/assets/ui/hunting-combat/png/skills/strike-icon.png | 83977 | Retired hunt asset; prior cleanup reviewed |
| game/assets/ui/hunting-combat/png/skills/strong-background.png | 286742 | Retired hunt asset; prior cleanup reviewed |
| game/assets/ui/hunting-combat/png/skills/strong-disabled.png | 252234 | Retired hunt asset; prior cleanup reviewed |
| game/assets/ui/hunting-combat/png/skills/strong-icon.png | 151505 | Retired hunt asset; prior cleanup reviewed |
| game/assets/ui/hunting-combat/svg/common/auto.svg | 5167 | Retired hunt asset; prior cleanup reviewed |
| game/assets/ui/hunting-combat/svg/common/speed-2x.svg | 4092 | Retired hunt asset; prior cleanup reviewed |
| game/assets/ui/hunting-combat/svg/skills/cooperation-effect.svg | 2028 | Retired hunt asset; prior cleanup reviewed |
| game/assets/ui/hunting-combat/svg/skills/strike-effect.svg | 1568 | Retired hunt asset; prior cleanup reviewed |
| game/assets/ui/hunting-combat/svg/skills/strong-effect.svg | 1861 | Retired hunt asset; prior cleanup reviewed |

## Verification
- Godot 4.5.1 imported the project and discovered dependencies after cleanup.
- Real Chapter 1 preparation, combat, victory and persistence tour: 128 checks passed.
- Stage catalog: 81 checks passed. Approved production VFX sequences/endpoints and Han field-skill tests passed.
- Project startup reached the entry flow with no missing-resource messages.
- Legacy approved-asset center checks failed on the same three existing buildings before and after cleanup. Desktop tests do not certify Android device playback or save migration.
