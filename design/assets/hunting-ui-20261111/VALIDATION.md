# 검증 결과

## 통과

- 에셋 매핑 46개: 신규 PNG25/SVG12 + 기존 원본/모델/폰트9. 경로·파일 크기·SHA-256 모두 일치.
- PNG 전체 디코딩, 1×1 빈 결과 없음. 투명 배경 확인. HP 채움 직사각형 2개만 의도적으로 완전 불투명.
- 비활성 스킬 3개 내부 RGB 동일(흑백), 금색 테두리 색 유지. 활성/피드백/비활성 합성 결과를 로컬 합성 이미지로 시각 검사.
- SVG12개 XML/viewBox 유효, 외부 URL·스크립트 참조 없음.
- Godot4.6.3의 격리된 검증 프로젝트에서 PNG25/SVG12 총37개 import 및 Texture2D 로드 성공, 최종 import/load 로그에 ERROR/SCRIPT ERROR 없음. SVG 효과를 Godot에서 PNG로 렌더하여 실제 레이어 합성도 확인.
- 기존 `node scripts/verify-demo-assets.mjs`: bundled assets165개 바이트/해시 검증 통과.
- 최신 준비·전투 Figma 캡처의 배치/내용 확인. Figma export용 임시 복제본은 제거했고 확정 원본2265:75,2319:340,2337:1123 보존 확인.
- 배경은 기존 formation clearing과 RGBA 픽셀 완전 동일, 초상3개는 기존 아틀라스 crop과 동일 원화 확인. 최종 묶음에서는 기존 Git blob을 그대로 재사용.
- 편성 패널의 Figma 원본 이미지 SHA-256은 기존 main right-panel.png와 동일. 나무판도 기존 투명 원본을 재사용.
- `git diff --check` 통과. 게임 스크립트·씬·프로젝트 설정·릴리스 workflow 변경 없음.

## 실행하지 않은 검사

- 실제 게임에 연결한 화면/상태 전환/전투 플레이 검증.
- Android/Windows 실제 기기 입력·성능·safe area·음향.
- 전체 `scripts/check-village.sh` 회귀 suite 및 앱 빌드. 에셋/문서 인계만 수행했으므로 게임 기능 통과로 보고하지 않습니다.
- 대상 프로젝트의 Godot4.5.1에서 최종 통합 import/렌더. 이번 포맷 확인 환경은4.6.3이므로 개발 브랜치의 정확한 엔진 버전으로 재검증하세요.

## CI 및 배포

현행 workflow 기준 이 `assets/…` 브랜치 push는 Android build/릴리스 정리 workflow 대상이 아닙니다. 이 작업에서는 workflow를 직접 실행하거나 main 병합·릴리스를 하지 않습니다. remote head 확인 결과는 작업 완료 보고의 commit으로 확인하세요.
