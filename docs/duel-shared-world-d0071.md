# D0071: Han / forest-deer laboratory

This experimental matchup uses a single SubViewport, World3D, metric floor,
orthographic Camera3D and transparent native render. The original rigs are
reparented from their preview adapters into two AnimatableBody3D nodes. Their
old individual viewport images are hidden and rendering is disabled. Switching
to any other matchup detaches the rigs and retains the original controller.
Campaign combat, damage values, attack cadence, SP and intro assets are unchanged.

Body and hurt volumes are separate CollisionShape3D capsules on layers1 and2.
They follow the sampled torso bones. A deterministic1/120s custom capsule solver
resolves both bodies' relative XYZ sweep together, including pose displacement.
The static floor is at y=0; foot samples cannot sink below it. This is a custom
kinematic solver, not rigid-body/ragdoll simulation. Authored planar root motion
is extracted once and limited by the current target's stand-off/body envelope.
Negative recovery root channels do not teleport the actor to its starting anchor.
The native jump height is preserved. Landings remain on the target's near side.

The spear tip is the original chipped-point attachment transformed through the
sampled right hand. Deer attacks use a head-mounted nose/horn probe. Only the
active attack interval is tested: previous-to-current weapon sweeps versus the
moving defender's hurt capsule, clipped at both interval boundaries. Capsule
contacts are continuous, so a fast tip entering and leaving in one render frame
is detected. Each committed action can hit once. Mere timer expiry or 2D distance
cannot call damage. Contacts from the same substep are ordered chronologically.
Small bounded shoulder pitch aims the real jab rig at torso height; there is no
screen-space body translation to make a tip match an effect pixel.

One contact packet drives unchanged authoritative damage, HP interpolation,
directional kinematic recoil, D0070 sounds and the existing D0070 painted impact,
blue charge/trail/afterglow effects. These project the real3D contact surface with
the common camera. D0070's authored fall-before-reward and mesh fade are retained.

Validation: `tests/duel_shared_world_tests.gd` covers common world ownership,
3D misses, active-window CCD,30/60FPS single hits, simultaneous crossing attempts,
moving-target landing, no teleport after misses, touch SP costs, pause, death and
manual/automatic reset, and leaving/re-entering this one matchup. The legacy
D0070 fixed2D tip/timer snapshots describe the replaced implementation and must
not be reported as passing physical-contact tests. Existing HUD checks are separate.
