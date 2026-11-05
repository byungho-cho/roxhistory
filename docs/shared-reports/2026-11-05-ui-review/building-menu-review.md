# Approved building menu and black submenu label

Source: `share/reference-assets` commit `d466d78a3a4e03714caf9d2afa9cbe452c438875`, `assets/ui/building-menu/v001/` and `assets/ui/labels/brush-black-v003.png`. Original bytes are preserved in `game/assets/ui/building-menu-v001/`. Five menu PNG hashes match the source manifest; all six PNGs are registered in the game manifest (163 images total).

Menu artwork is composed from the separate circular base and icon. Manifest visible bounds are used without editing the original PNGs; icons occupy 68% of the circle. Upgrade is larger, close is smaller with a 44px touch area. The menu projects the selected building's location into screen coordinates and clamps above the bottom action row. Selection uses stable saved building IDs, not an array index that can change after demolition.

Click or 650ms hold opens the menu. Release after a hold is consumed, UI buttons own their touches, an outside tap dismisses without moving the hero, and map/modal/background changes dismiss selection. A seed reward is collected by tapping its bubble; tapping the building itself opens its menu. Unclaimed rewards block demolition.

Movement is disabled and labeled `이동(예정)`. Resident upgrades are unavailable; the chief upgrade routes to the existing guarded workflow and explains missing prerequisites/assets. The chief cannot be demolished. Resident demolition retains the existing confirmation, saved cost/refund policy and atomic transaction; the popup now uses the supplied close and demolition icons. A current 20/20 hut refunds 18/18 exactly once. Cancellation does not change data.

The black brush uses its visible alpha bounds, 82% overall opacity, centered separate text, and the already-approved four-pixel submenu offset / half-label overlap. The brown candidate is not used.

Validation: 19 menu/input/transaction checks passed, including synthetic touch hold/release, cancel, duplicate confirm, exact refund and reload. Desktop rendered resident/chief menus, icon confirmation, black labels and portrait placement; the preview leaves save state unchanged. Existing workflow checks previously passed 20 cases. Physical Android touch/performance remains unverified.

Local APK target: 0.1.39 / version code 40, same package and signing certificate as the existing release. This includes terrain candidates and building workflow wiring absent from 0.1.38. APK publication and main merge are not authorized by this source change. Outpost placement/final building-stage assets, relocation, and remaining Library-only return/bubble artwork remain incomplete.
