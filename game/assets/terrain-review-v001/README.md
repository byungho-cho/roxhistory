# 마을·월드 배경 2안 공유

원본 에셋을 `assets/` 아래 역할별로 분류했습니다. `share/reference-assets` 브랜치에만 저장하며 main과 게임 실행 코드는 변경하지 않습니다. 파일별 위치·SHA-256은 manifest.json을 참조하세요. 향후 리소스 패키지는 assets 아래 필요한 파일을 묶어 생성할 수 있습니다.

배경 PNG에는 지형 디테일이 포함될 수 있으므로 실제 픽셀을 보고 기존 산·강 오브젝트와 중복을 확인해야 합니다. 현재 맵은 게임 내 시각 검증 전 후보이며 자동 배포용 완성본이 아닙니다.

## 적용 및 검증 한계

RoxHistory terrain candidates, 2026-11-05

Village: 1672 x 941 native generated image. Wider composition, not a 4K asset. Central region stays clear for runtime objects. If mapped to 3000 x 1688 world pixels, texture is approximately 1:1 at zoom .56 and enlarged 2.87x at zoom 1.6. Do not label as high-resolution or promise crisp maximum zoom. Prefer small detail texture overlays at close zoom, or split terrain into bounded-density ground tiles and separate peripheral objects. Do not simply enlarge the PNG and call it new detail.

World Ground A/B: 1254 x 1254 each. Unmodified source images are NOT pixel-perfect seamless. Original edge mean absolute RGB differences (0..255): A horizontal 5.21, vertical 6.04; B horizontal 4.29, vertical 3.78. Interior adjacent-pixel means: A 2.61, B 2.10.

Non-destructive seam handling recommendation:
Repeat A with alternating horizontal and vertical mirroring. In shader coordinates p (continuous tile units), sample UV = 1 - abs(mod(p,2) - 1). Thus both sides of each join sample the same source edge. Numerical edge identity check gives max difference 0 for mirrored joins. Do not randomly rotate individual cells as it breaks this invariant. This removes color jumps but may show mirrored pattern symmetry; visual game validation still required. B should be a local dirt patch blended by an organic feathered mask over continuous A rather than hard-switching individual adjacent A/B cells. Use same world-anchored UV on all chunks so camera movement does not slide texture or create new seams.

Fog: 1774 x 887, genuine RGBA, alpha range 0..255. 31.1% fully transparent; 68.9% semi-transparent, center median alpha 252. It is a separate cloud sprite, not terrain. Apply an additional edge feather if tiling cloud sprites because wisps touch a few canvas edges. Exploration reveal should be driven by a separate world-space visibility mask, not baked into the map. No visibility/game logic implemented.

Validation limits: no game code changed; no Android/Godot scene render verified. Browser repeat-test screenshot blocked by local Chromium socket execution restriction. Numerical mirrored-edge checks passed; full visual repetition quality and GPU performance not verified. All maps remain candidates until in-game review.
