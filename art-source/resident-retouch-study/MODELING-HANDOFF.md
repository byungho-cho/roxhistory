# Focused resident modeling handoff (protagonist remains unchanged)

Target: C10000 approved B simple 2D woodcutter, Figma node 1161:12. Adult male, simpler ochre one-shoulder hide clothing, bare feet, short/swept chestnut hair or low nape bundle. Do not copy the child protagonist's fur cape, large topknot, bracelets or boots.

Reuse existing rig and locomotion. New skeleton/animation package is NOT required if the existing 15-bone rest transforms can be retained. Existing hero and production residents must not be overwritten. One woodcutter first; other occupations follow only after acceptance.

Needed art work:
1. Face/neck: adult jaw and smaller eye proportions; current copied hero face still reads childlike. Re-sculpt and repaint coherently rather than scaling the entire head.
2. Hair: replace joined hero hairstyle with one coherent cap and swept locks. Current procedural crown reads as an added plate; moving original topknot geometry stretched the topology and was rejected.
3. Anatomy: connected shoulders/elbows/wrists/ankles, detailed but restrained hands and barefoot silhouette. The current voxel-joined blockout is smooth but fingers/toes lose definition.
4. Clothing: preserve current plain asymmetrical worker silhouette; add restrained worn-hide texture and edges consistent with the approved illustration. Separate enough from skin to avoid clipping in walking, mining and carrying poses.
5. Mobile mesh: budget only after looking at final silhouettes and device performance. Do not aggressively decimate UV-split legacy mesh; our 16k trial caused visible cracks. Prefer proper topology/LOD. Reference existing runtime residents around 16k triangles and 1024px textures, but do not certify performance from counts alone.

Deliver .blend + GLB, textures embedded or included, named material groups, clean face/hair/clothing meshes, scale and feet aligned to existing source. Keep bones: hips, spine, head, armL, forearmL, handL, armR, forearmR, handR, thighL, shinL, footL, thighR, shinR, footR. Reuse source rig (rest orientations matter, not just bone names).

Carrying props remain separate: wood bundle / stone basket / grain basket. Attach using spine/back or hand socket; not baked into resident skin. Existing jobs.entry(resident_id).cargo.kind supplies resource type. Show only while cargo amount >0, hide after successful delivery, retain while destination temporarily unavailable. Do not alter resource credit timing or movement speeds. Each prop may need attachment offset and a dedicated arm pose; no full new walking animation is needed initially.

Acceptance: neutral front/side/back at game-size and enlarged; walking loop; wood/stone working poses; carrying loaded/empty; no neck/wrist/garment gaps; model identification distinct from protagonist; gameplay frame-time on Android. Rig algebra tests alone are insufficient.
