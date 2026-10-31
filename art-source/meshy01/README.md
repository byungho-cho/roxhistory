# Meshy01 주인공 편집 원본

- 사용자 제공 `Meshy_AI__01.glb`를 선택했다. 원본은 사용자의 `D:/roxhistory/01. asset/`에 보존했다. 입력 SHA-256과 관절 위치는 [model-provenance.json](model-provenance.json)에 있다.
- `Meshy_AI_02.glb`도 같은 조명에서 비교했다. 01의 따뜻하고 무광에 가까운 인상이 기존 배경과 더 잘 맞았다. 두 원본 모두 1,745,859삼각형이며 스킨·애니메이션이 없었다. 동일한 메시라는 뜻은 아니다.
- [meshy01-hero.blend](meshy01-hero.blend): 60,000삼각형, 원본 텍스처를 포함한 편집 가능한 메시·15본 리그·버텍스 가중치. Blender 4.5.3 LTS에서 제작했다.
- [게임용 GLB](../../game/assets/characters/meshy01/hero.glb): 같은 편집 원본에서 내보낸 파일. 원본 얼굴·머리·옷·체형을 유지하고 거칠기 0.92, 스페큘러 0.12, 노멀 강도 0.22로 조정했다.
- [재현 스크립트](../../tools/prepare_meshy_hero.py): 원본 정규화 → 6만 삼각형 단순화 → 관절 생성 → 해부학적 구역 가중치 → UV 경계를 공유하는 표면 가중치 평활화 → BLEND/GLB 저장. `--reuse`는 이미 생성된 최적화 메시에서 가중치만 다시 생성한다.
- 모바일 텍스처는 원본을 보존한 채 Godot 임포트에서 2,048px·밉맵·GPU 압축(ETC2/S3TC)을 적용한다.
- 걷기·대기·채집·건설 동작은 [HybridCharacter](../../game/scripts/hybrid_character.gd)가 실제 스켈레톤에 적용한다. GLB에 미리 녹화한 동작 클립이 있다는 의미는 아니다. 얼굴 표정·눈 깜박임·개별 손가락 리그는 아직 없다.

```text
blender --background --factory-startup --python tools/prepare_meshy_hero.py -- Meshy_AI__01.glb output-directory
```

출처·사용 조건: 사용자가 RoxHistory 적용을 위해 직접 제공한 Meshy 결과물이다. 원본을 자체 제작 모델로 표시하지 않는다. 제작 계정의 플랜별 Meshy 이용 조건·상용 사용 권한은 독립적으로 확인하지 않았다. 수정 리그와 재현 스크립트는 이 저장소의 개발 작업이다.

## 개발용 성능 진단

디버그 빌드에서 `--test-ui`와 함께 `--profile-static-hero` 또는 `--profile-no-hero`를 넘기면 정지/비표시 조건을 분리할 수 있다. `--profile-short`는 60프레임 준비 후 120프레임을 측정한다. 일반 실행은 항상 3D 애니메이션과 600프레임 측정을 사용한다. 화면에 2D/3D 비교 메뉴를 다시 추가한 것이 아니다.
