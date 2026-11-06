# 0.1.47 review

Single ground-only trial background from approved commit 9c09a9f96ee020558adcea9cf5fb405ad8c57473, original 1672x941 PNG byte-verified. One sprite covers Rect2(-1200,-675,4800,2700), replacing rendered repeated/mirrored surround. Old source assets remain preserved. Trees, stones, buildings and other gameplay objects remain separate, at unchanged saved coordinates. No save migration/reset, resource grants, movement boundary expansion or site-capacity change.

Includes integrated-v002 menu commit 8a2f573: downward menu placement, close at building right, integrated icon/name PNGs, side hut aligned above construction with outpost left. Move remains hidden/disabled pending wording/display decision; no movement feature. Gold connecting line omitted as permitted. Old ground selection outline not added.

Validation: 684 state/save checks and 57 integrated-menu checks passed. Actual desktop GL captures at 1280x720 and 540x960, zoom 0.56 and 1.6, show one continuous background and no exposed image edge. Coverage assertions passed using internal viewport coordinates (initial test incorrectly used window pixel dimensions; corrected). Max zoom is visibly soft. Test screenshots: game/reports/ground-047-*.png (local ignored artifacts). Existing user saves were never opened; isolated test profiles used.

Quality limits: source stretched to 4800x2700 world units gives approximately 2.45 screen pixels per source texel at 720p max zoom, 3.67 at 1080p. Source has repeated-looking painted motifs even though renderer uses one image. Raw RGBA estimate 6 MiB, mipmaps disabled; this is not measured Android memory or total app RAM. Physical Android performance/touch/memory testing not performed. Existing reserved shoreline collision remains despite no river artwork in this ground-only candidate; current playable polygon keeps it outside normal village travel. Expanded 20-30-building layout and fixed 90% expanded boundary are NOT implemented in this rapid trial release.

Package com.roxhistory.demo, versionCode 48, versionName 0.1.47. Signature matches prior APK. Install as update, do not uninstall to preserve existing data.
APK SHA256 AD97B66DD5A6063188C22D8B04A6CBF1A24B3711DCD41084C1B53F6DB28E2591.
