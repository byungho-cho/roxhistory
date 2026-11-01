# 에셋과 편집 원본

Figma 파일: https://www.figma.com/design/zkbflw9fCdAlWbphhw5pSS
획득일: 2026-11-01 KST. 사용자가 지정한 프로젝트의 최신 디자인 원본. 외부에 별도 재배포할 권리를 새로 주장하지 않는다. I100의 90·아카이브는 사용하지 않았다.

실제 원본과 런타임 파일은 `game/assets/figma-latest/`, 정확한 크롭은 `game/scripts/figma_art.gd`에 보존한다. 임시 Figma 다운로드 URL은 실행 코드에서 사용하지 않는다. 원본 비율과 투명도를 유지하고 atlas crop으로 분리한다. 버튼은 양끝 3분할, 패널은 모서리 9분할로 크기를 바꾼다.

| 파일 | 용도 | Figma 원본 |
| --- | --- | --- |
| 94b86.png | 전체 지도 및 일반 확대 | A303 215:1136 / 219:1032 |
| map-jeongok-detail.png | 전곡리 선택 상세 원화 | 215:666 (215:664 내부) |
| 772af.png | 주먹도끼·빗살무늬토기·홍합 | I100 350:260 / 323:46 |
| b7632.png, meat.png | 목재·돌·열매·도토리·고기 | I100 331:46, 고기 354:9 |
| 3135e.png | 가방·나침반 | I100 327:46 |
| 023a3.png | 뒤로·복원·창·집·두루마리·뿔피리·도끼 | I100 331:47 |
| 94e05.png | 종이 패널 | A303 215:1136 상세 패널 |
| be529.png | 금색 버튼 | A303 215:1136 시작 버튼 |
| 513aa.png | 돌 새김 무늬, 불투명도 26% | A303 215:1136 상세 패널 |
| title-region.png | 첫 터전을 고르세요 | 292:1268 |
| title-jeongok.png | 전곡리 석재 제목 | 336:503 |
| title-amsa.png | 암사동 석재 제목 | 336:84 |
| title-dongsam.png | 동삼동 석재 제목 | 292:1279 |
| stone-title-surface.png | 공통 제목 석재 표면 원본 보존 | 360:145 / 360:154 |
| SVG 원본 | 지명 음영·연결선·선택/비선택 점·구분선·접지 그림자 | A303 215:1136 / 215:1018 |

제목은 Figma 노드의 `exportAsync` 투명 PNG를 사용한다. 텍스트 의미·접근성 이름도 코드에서 관리한다. 실행 캡처에는 실제 게임 UI가 들어 있으며 화면 전체를 정적 이미지로 덮지 않는다.

Black Han Sans Regular, Do Hyeon: Google Fonts 공식 원본, SIL OFL. 폰트와 OFL 전문은 `game/assets/fonts/`에 함께 저장했다. 기존 Noto Sans KR도 유지한다.

주인공·정착지·음향은 기존 승인 작업을 재사용했다. 모델을 새로 제작하거나 권리를 바꾸지 않았다. 이전 출처는 [v0.1.10 보고서](../2026-10-31-region-selection/report.md) 참조.
