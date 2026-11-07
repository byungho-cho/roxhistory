# v0.1.52 — Figma 비용 표시 원본

2026-11-07 Figma 최신 노드에서 받은 원본 PNG. 재생성·재채색하지 않았으며 게임 숫자와 버튼 입력은 코드로 연결합니다.

|에셋 ID|파일|Figma 노드|적용|
|---|---|---|---|
|UI-BUILD-COST-BRUSH|cost-brush.png|1437:6984 / 1437:7032|배치 중 건물 아래 비용, 60% 불투명도|
|UI-UPGRADE-COST-SLAB|upgrade-slab.png|1427:6916 / 1426:320|업그레이드 비용판, 원본 투명 여백을 유지하며 Figma와 같은 클립|

원본 크기와 SHA-256은 `game/data/assets.json`에서 관리합니다. 같은 규격의 로컬 리소스를 AssetCatalog로 교체할 수 있으며 비용·점유·저장에는 영향을 주지 않습니다. 원본에 포함된 투명 여백을 임의로 잘라 덮어쓰지 않습니다.

- 확인·취소: 기존 `assets/ui/v034/build-confirm.png`, `build-cancel.png` 재사용.
- 업그레이드 공통 화살표: 기존 확정 `assets/ui/building-menu-integrated-v004/upgrade-*.png` 재사용.
- 자원 아이콘: 기존 FigmaArt/DemoArt 목재·석재 원본 재사용.
- 퀘스트: Figma 529:132의 반투명 패널·금색 강조선·자원 행 구조. 현행 본부/주민 목표와 실제 자원 수치 표시.
- 주민 말풍선: Figma 1140:520의 짙은 초록 배경·금색 제목·밝은 안내 2행. 실제 인원/빈자리 안내로 연결.
- 사용 출처: 프로젝트 소유 Figma `zkbflw9fCdAlWbphhw5pSS`. 외부 신규/유료 자산 없음.
