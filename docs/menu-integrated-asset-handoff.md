# Integrated building-menu asset handoff (proposed export dimensions)

User decision: each menu item combines its icon and final menu name into one transparent asset. Do not implement a temporary icon-plus-live-label substitute. Final artwork is pending. This document proposes a production contract, not approval of new artwork or wording.

At a 960x540 logical reference viewport:

| Asset | Proposed display canvas | PNG export at 3x | Notes |
|---|---:|---:|---|
| Building actions, each | 96x96 | 288x288 RGBA | Icon, circular base and centered black-brush label in one image; identical canvas/pivot across states |
| Close X | 48x48 | 144x144 RGBA | Visible symbol/button about 32–36; independent touch region at least 44 |
| Side-menu hut/outpost, each | 72x80 | 216x240 RGBA | Building icon plus centered black-brush name; same lower baseline and transparent margins |

The building-action circular center can be (48,36), with a 52–64 diameter depending on emphasis; reserve y70–92 for the brush/name. These dimensions are a proposed starting point to reconcile the reference with mobile readability; use the approved final export's actual anchors if design differs. Supply full bounds and circular center/label bounds in a manifest. Keep state canvases identical so hover/press/selection cannot jump.

Provide normal and disabled states; provide a selected/highlighted state where the approved design calls for a gold glow. Optional pressed state can use the same dimensions. The move item's final function and wording remain for the user to decide; do not bake the current provisional code text into production art. Keep editable source alongside flattened PNGs.

Placement contract: selected building ground contact anchors a downward U, with center action lower than the sides. Close X anchors separately to the building's right side, not to the menu's lower center. Side hut/outpost form a horizontal row directly above construction, with hut's center aligned to construction's center; final side order/spacing should follow supplied art without displacing that anchor. Gold connecting arc may be omitted. Ensure menu/close touch areas are distinct and no background click passes through.

When bottom HUD leaves insufficient space, keep the U direction: review a small camera framing adjustment or approved layout compression rather than clamping the entire menu above its building. Portrait/landscape and min/max zoom need actual captures with the final assets. No code layout or APK change is authorized before those assets arrive.
