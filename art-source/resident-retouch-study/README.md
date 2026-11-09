# 주민 리모델링 · 선택 실행 시험안

기준: `a1f149f379b4d62fdb93aa49952171e7a02c2698` (0.1.71 main).
최종 승인 모델 또는 배포본이 아닙니다. 주인공 원본과 기본 실행 동작은 유지합니다.

## 실행 및 개발 이식
```sh
godot --path game -- --resident-retouch-study
```
플래그 사용 시 sturdy_male 주민만 새 모델을 사용합니다. 여성 주민은 기존 모델을 유지합니다. 시험 모드 주민의 `cargo.kind`와 양에 따라 나무·돌·곡식 등 소품을 spine에 별도 부착하고, 빈손이면 숨깁니다. 기본 실행에서는 기존 모델과 동작을 그대로 사용합니다. 경제·저장·주민 배정 규칙은 변경하지 않습니다.

- 모델·소품: `game/assets/characters/resident-study/`
- 연결: `game/scripts/trial_resident.gd`, `game/scripts/resident_carry_study.gd`
- 편집 원본: 이 폴더의 `woodcutter-study.blend.part01`~`part03` (전송 크기 제한 때문에 무손실 분할)
- Figma 참고: https://www.figma.com/design/zkbflw9fCdAlWbphhw5pSS?node-id=1161-12
- 원본 주인공: `art-source/meshy01/meshy01-hero.blend`, 수정하지 않음

최신 개발 브랜치에 적용할 때 별도 브랜치에서 차이를 검토하세요. 다른 개발 작업을 덮어쓰거나 이 시험안을 곧바로 출시용으로 간주하지 마세요.

## 작업 내용과 품질 한계
기존 15개 골격과 동작을 재사용하고 복제 모델의 주인공 복장·장화 대신 단순한 갈색 가죽옷, 맨발, 성인 체형을 구성했습니다. 몸 연결부를 remesh하고 가중치를 옮겼습니다. 얼굴·머리카락·손발은 추가 조형이 필요하며 승인 2D 원화의 정확한 재현은 아닙니다. 약 58,212 triangles로 모바일 최적화가 필요합니다. 운반 소품은 초기 blockout이며 손 동작/실제 가림 확인이 필요합니다.

`model-comparison.png`와 `carry-props-placement-study.png`는 Blender 렌더이며 실제 게임 캡처가 아닙니다. 실제 게임 화면은 이 환경의 화면 소켓 제한으로 확인하지 못했습니다. Android 성능도 미확인입니다.

## 검사
```sh
godot --headless --path game --script tests/resident_retouch_study_test.gd
godot --headless --path game --script tests/resident_retouch_integration_test.gd -- --resident-retouch-study
godot --headless --path game --script tests/resident_retouch_integration_test.gd
godot --headless --path game --script tests/resident_jobs_tests.gd
```
- 골격/동작: 5,431 checks 통과
- 시험 모드 연결: 25 checks 통과
- 기본 모드 유지: 4 checks 통과
- 기존 주민 작업 테스트: 25 checks 통과

기존 jobs 테스트 실패는 수정 전 HEAD에서도 재현했습니다. 구형 `family_joined` 단독 fixture 대신 roster/count 및 촌장집을 준비하고, 현행 만재 도착분 폐기 기대값으로 변경했습니다. 보고서 폴더 생성과 쓰기 실패 처리도 보완했습니다. 실제 게임 로직을 테스트에 맞춰 바꾸지 않았습니다. 전체 회귀 검사 완료를 의미하지 않습니다.

main 병합·배포·빌드는 하지 않습니다.

## Blender 원본 복원
Linux/macOS: `cat woodcutter-study.blend.part* > woodcutter-study.blend`
Windows cmd: `copy /b woodcutter-study.blend.part01+woodcutter-study.blend.part02+woodcutter-study.blend.part03 woodcutter-study.blend`
복원된 파일은 Blender에서 바로 열 수 있습니다. 압축·분할 전후 모델 내용은 동일합니다.
