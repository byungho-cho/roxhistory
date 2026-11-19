# RES-050 model reform, 2026-11-20

Approved source: https://drive.google.com/drive/folders/1HgFqzdJdKsJ7ZZLD8XZsb4YtCDCoqmlp

The three GLBs in this directory and the four GLBs under `assets/animals/res050`
are byte-identical to `01-models`. All seven SHA-256 values were checked against
the supplied `FILES-SHA256.csv`. Previous source assets remain intact.

Use their native REQ045/046/047 clips; older D0066 supplements must not replace
the reform channels. Existing runtime speed profiles and the approved external
run-C animations remain in use. New gameplay callers are not added here.

The supplied shield-counter attachment patch is adapted in `uram_lab_rig.gd`.
The existing club/shield textures are byte-identical to the supplied equipment
art. No preview loader or simplified character implementation was copied.

Support transfer metadata is now 2.72 native seconds. The existing model-test
handoff slots (0 / 1.05 / 2.65 seconds) and live gameplay judgments are retained;
future combat integration must review this timing mismatch explicitly.

Imports retain the supplied keys at 60fps with animation optimization/compression disabled. Native raw/deployed bone-pose checks use the same 60fps bake settings.
