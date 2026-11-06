# 0.1.49 village edge decoration

Approved four transparent PNGs copied byte-for-byte from 6ee87c8ff9dfb1158733dbc56e08b9c8b566f6b0, assets/environment/village-edge/v001. Runtime copies: game/assets/village-edge-v001; manifest records source dimensions and SHA256. Full source transparency/padding retained; runtime anchors use image alpha bounds.

Two small distant mountains are placed at world x=500/1100 with lower edge y=-420, outside the fixed playable top y=-410. Visible alpha widths 260/330 world units. They are deliberately small in the thin overview top band; portrait framing shows only the mountain within its camera view. They are decoration without collision, below gameplay sprites and HUD. Natural mountains remain eligible for GPS rendering.

Four diagonal clouds replace the previous fog sprites. World centers (-950,-540), (3350,-540), (-950,1890), (3350,1890), alpha-bound width 600, maximum opacity .30. Only thin corner portions enter the overview. Fade to hidden by zoom 1.25, including maximum 1.6; clouds excluded from GPS. Narrow portrait framing may show no corner clouds because corners remain world anchored. No screen-following overlay or expanded movement collision.

74 movement/save/resource checks passed, including negative-coordinate travel and reload. Actual GL desktop captures reviewed at 1280x720 and 540x960, minimum and maximum zoom. Assertions verified two mountains entirely outside playable bounds, four clouds, maximum-zoom cloud hiding and full background coverage. No gameplay save/schema/coordinates/menu changes from 0.1.48.

Known limits: source edges have faint color fringes; the supplied PNGs were not retouched. Existing low-resolution ground softness remains. Android physical-device memory/performance/touch tests not performed. Existing package/signature retained, versionName 0.1.49, versionCode 50. Install as an update; do not uninstall.
