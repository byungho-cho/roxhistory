# 농장 에셋 인수인계 · 2026-11-08

사용자 승인 외형 및 직접 조정한 Figma 크기를 기준으로 내보낸 PNG입니다.
게임 코드·현재 개발자 구현·런타임 파일은 변경하지 않습니다.

## 파일

| 파일 | 크기 | 용도 |
|---|---|---|
| farm-l1.png | 420×320 | 농장 L1 완성 외형 |
| farm-l2.png | 440×340 | 농장 L2 완성 외형 |
| farm-l3.png | 480×380 | 농장 L3, 뒤쪽 두 면 울타리·허수아비 |
| farm-l4.png | 520×420 | 농장 L4, 높은 사방 울타리·허수아비 |
| grain-growth-01~04.png | 각 580×580 | 재사용할 곡식 성장 4단계 |
| menu-farm-normal.png | 216×240 | 농장 아이콘+이름 조합 |
| menu-farm-locked.png | 216×240 | 잠김 상태, 좌하단 자물쇠 64.8px |

모든 PNG는 RGBA이며 실제 투명 영역이 있습니다. 사용자 Figma 이미지의 투명도도 그대로 보존했습니다.
PNG 프레임 크기를 게임 월드 크기로 그대로 적용하지 말고 기존 건물 표시·점유 영역 규칙을 사용하세요.

## 주의: 완료 외형과 성장 레이어를 구분

`farm-l*.png`는 **곡식이 포함된 완성 외형**입니다. 빈 밭·울타리·허수아비와 곡식이 레이어별로 완전히 분리된 상태는 아닙니다.
따라서 위 완성 외형 위에 성장 이미지를 다시 올리면 작물이 이중으로 보입니다.
빈 밭을 자동 생성하거나 기존 임시 밭으로 몰래 바꾸지 말고, 성장 조합용 최종 바닥은 별도 준비해야 합니다.
이전 흙 복원 검토용 바닥 4종은 최신 울타리 승인 외형과 다르므로 본 패키지에서 제외했습니다.

## 최신 메뉴 적용 기준

- 오른쪽→왼쪽: 움집·농장·훈련소·화덕·신당·초소
- 사용자 수정한 건물·레이블 상대 위치를 유지합니다.
- 잠김 자물쇠는 왼쪽 하단, 기존 43.2px에서 1.5배인 64.8px입니다.
- 조합 이미지에는 이미 이름과 자물쇠가 포함되므로 별도 텍스트/잠금 아이콘을 중복 표시하지 마세요.
- 분리 컴포넌트 방식으로 구현할 경우 아래 Figma 원본을 사용합니다.

## 기준 Figma

- B10000 · 07 농장 분리: https://www.figma.com/design/zkbflw9fCdAlWbphhw5pSS?node-id=1706-14
- S40200 · 03-07 곡식 성장: https://www.figma.com/design/zkbflw9fCdAlWbphhw5pSS?node-id=1693-87
- I10000 · 03-02 메뉴 출력: https://www.figma.com/design/zkbflw9fCdAlWbphhw5pSS?node-id=1277-243
- I10000 · 사용자 수정 메뉴 배치: https://www.figma.com/design/zkbflw9fCdAlWbphhw5pSS?node-id=1295-229
- B10000 · 채집·생산 규칙: https://www.figma.com/design/zkbflw9fCdAlWbphhw5pSS?node-id=1686-14

## 기획 참고

농장 수는 촌장집 L1~4에 따라 1/2/3/3, 주민 움집 1채 이상 건설 시 해금.
목재 10/20/30/50, 석재 5/10/20/30, 건설·업그레이드 1분/10분/30분/3시간.
성장 10분, 준비 1분 별도. 총 생산 5/10/24/40, 수확 1/2/3/4회, 동작 1.2초.
이동·운반은 주인공 공통 걷기 속도와 실제 경로 기준. 자원 표시명은 씨앗이 아닌 곡식.

이 커밋은 **에셋 저장**이며 게임 적용·빌드 완료를 의미하지 않습니다.

## Runtime integration

Imported from PR #67, source commit 3f17c6b75fe2af6808f9ab9557755cf8012fa660.
Completed and preview farms use the matching L1–L4 image at the existing world footprint scale. Menu art includes its own text and locked badge; no duplicate labels/badges are drawn.
Growth images are retained but intentionally unused: completed farm art already contains crops. Runtime crop marks were removed. Preparation/growth/harvest timers and production remain unchanged; the fixed crop appearance does not visualize those phases. Clean empty-field and crop layers are still required.
Validation: farm_assets_v002_tests 19/19; resident_farm_v0161_tests 131/131; Godot import passed. Runtime capture: game/reports/farm-assets-v002.png (local ignored output). No APK/EXE export or publication performed during this integration.
