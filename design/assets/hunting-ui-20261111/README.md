# 사냥 준비·전투 최종 UI 에셋 인계 (2026-11-11)

이 변경은 **에셋과 개발 지시문만** 제공합니다. 게임 코드, 밸런스, 실행 동작, 배포는 변경하지 않았습니다.

- [준비 확정 화면](https://www.figma.com/design/zkbflw9fCdAlWbphhw5pSS?node-id=2265-75)
- [전투 최신 화면](https://www.figma.com/design/zkbflw9fCdAlWbphhw5pSS?node-id=2319-340)
- [전투 종료 확인](https://www.figma.com/design/zkbflw9fCdAlWbphhw5pSS?node-id=2337-1123)
- [개발 지시문](DEVELOPMENT.md)
- [파일·Figma·기존 모델 매핑](manifest.json)
- [권리·출처와 미포함 범위](PROVENANCE.md)

## 구성

- `png/`: 투명 PNG 25개. 최신 스킬 배경·아이콘·비활성, HP/VS, 뒤로가기·가방·붓터치, 문구 없는 준비/종료 버튼과 팝업 바탕.
- `svg/`: 벡터 SVG 12개. 스킬 효과 3개, 활성/비활성 청옥 구슬, 편성 셀·카드·교체, AUTO/X2.
- `layout/`: Figma의 실제 좌표·계층·컴포넌트 연결을 읽은 JSON. 좌표계는 1920×1080. 숨김 보존 노드는 `visible: false`이므로 화면에 다시 표시하지 마세요.
- 전체 화면 참고는 위 Figma 링크를 사용합니다. 미리보기 이미지 파일은 이번 GitHub 게시에서 제외했습니다. 실행용 에셋은 무손실 PNG/SVG입니다. **완성 화면 스크린샷을 게임 UI로 사용하지 마세요.**
- `validate_assets.py`: 바이트·픽셀·투명도·SVG·매핑 검증.

## 기존 자산 재사용

기존 편성 개발 커밋 `cb74af74ad4bcd98eb98072798b3b3e73f50858b`에서 배경 `clearing.png`, 초상 아틀라스 `portraits.png`의 **기존 Git blob을 그대로** 같은 `game/assets/ui/hunting-formation/` 경로로 가져왔습니다. 별도 재압축 복사본이나 초상 3개 잘라낸 파일을 중복 추가하지 않았습니다.

나무판·편성 패널·4개 GLB·한국어 폰트는 현재 main의 기존 파일을 참조합니다. 경로와 SHA-256은 manifest의 `reused`에 있습니다. 4개 모델은 Figma의 정지 스프라이트를 대신하는 기존 런타임 모델이며, 이 인계가 새로운 리깅·동작 클립을 제공하는 것은 아닙니다.

## 사용 계약

1. 스킬은 512×512 공통 캔버스에 `background PNG → effect SVG → icon PNG` 순서로 겹칩니다. 평상시 효과 층은 숨깁니다. 비용 구슬은 버튼에 합쳐져 있지 않습니다.
2. 비활성 PNG는 확인된 정적 대체 이미지입니다. 동적 구현에서는 동일 내부 마스크(중심 256,256 / 반지름 213) 안만 흑백 처리하고 금색 외곽은 유지하세요. 입력 효과는 숨깁니다. 원형 밖으로 아이콘을 키우지 마세요.
3. `logical_size`는 Figma 노드 크기, `pixel_size`는 그림자·외곽선을 포함한 실제 PNG 크기입니다. `render_offset`과 `render_size`를 적용해야 버튼/HP 외곽을 압축하거나 잘못 정렬하지 않습니다.
4. 준비 버튼은 문구 없는 바탕입니다. `빠른 출전`(36px), `전투 시작`(50px), 팝업 `종료`·`계속`(36px)은 Noto Sans KR Bold 런타임 Label로 표시하세요. 수치·지역명·이름·레벨·편성 인원도 런타임 텍스트입니다.
5. HP는 `hp-track` 위에 310×54 채움을 (5,5)에 놓고 너비를 마스크로 조절합니다. 1,260/920은 Figma 예시 값이며 게임 밸런스가 아닙니다.
6. SVG에는 외부 URL·스크립트·폰트 의존성이 없습니다. AUTO/X2의 고정 문구는 벡터 윤곽으로 내보냈습니다. 동적 라벨이나 접근성 이름은 별도 Control에서 유지하세요.
7. 배포용 프로젝트에 복사할 때 각 파일을 한 번만 넣고 manifest의 경로 매핑을 갱신하세요. 이 폴더를 통째로 게임 리소스에 복사하여 문서까지 번들하지 마세요.

## 검증

저장소 루트에서:

```sh
python3 design/assets/hunting-ui-20261111/validate_assets.py
node scripts/verify-demo-assets.mjs
```

검증 결과와 Godot SVG/PNG 로드 확인은 `VALIDATION.md`에 기록합니다. 에셋 검증은 실제 입력·전투·모바일 렌더링 테스트를 대체하지 않습니다.
