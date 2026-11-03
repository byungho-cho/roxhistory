# 주변 인물 3D 원본 모델

보관일: 2026-11-03 KST. 사용자가 제공한 Meshy GLB **5개를 원래 파일명·바이트 그대로 Git LFS에 저장**했습니다. 지난 동물 3D 원본과 같은 보관 방식이며, 이후 개발 담당의 모델 검토·최적화·리깅·게임 연결에 사용합니다.

| 원본 파일 | MiB | 삼각형 수 | 스킨 | 애니메이션 |
| --- | ---: | ---: | ---: | ---: |
| [Meshy_AI_Gentle_Elder_Wanderer_1103004549_generate.glb](Meshy_AI_Gentle_Elder_Wanderer_1103004549_generate.glb) | 22.64 | 989244 | 0 | 0 |
| [Meshy_AI_primitive_girl_remesh_1103003606_texture.glb](Meshy_AI_primitive_girl_remesh_1103003606_texture.glb) | 25.71 | 10442 | 0 | 0 |
| [Meshy_AI_primitive_girl_cartoo_1103014930_generate.glb](Meshy_AI_primitive_girl_cartoo_1103014930_generate.glb) | 25.84 | 1128970 | 0 | 0 |
| [Meshy_AI_Friendly_Caveman_1103011451_generate.glb](Meshy_AI_Friendly_Caveman_1103011451_generate.glb) | 0.27 | 15716 | 0 | 0 |
| [Meshy_AI_Friendly_Caveman_1103011940_generate.glb](Meshy_AI_Friendly_Caveman_1103011940_generate.glb) | 22.49 | 982564 | 0 | 0 |

[파일별 크기·SHA-256·GLB 구조 검사](manifest.json). 삼각형 수는 고유 메시의 primitive/accessor 기준이며 씬의 반복 인스턴스 수나 실제 엔진 렌더 비용을 뜻하지 않습니다.

## 보관과 구현 상태

- GLB 2.0 헤더·길이·JSON 구조와 원본/복사본 SHA-256을 확인했습니다. 실제 렌더링·외형 대조·Godot/Android 실행 검증은 이번 보관에 포함하지 않았습니다.
- 원본 축소·재질 교정·텍스처 변환·리깅·애니메이션·게임 적용은 수행하지 않았습니다. 원본에서 파생한 게임용 모델은 별도 버전과 경로로 관리합니다.
- skins와 animations가 없는 파일은 보행 리그/동작이 준비됐다고 기록하지 않습니다. 단순 노드 계층만으로 리깅 완료라고 판단하지 않습니다.
- 승인된 [2D 주민 원화8종](../../residents/v001/README.md)과 각 GLB의 대응 관계는 미지정입니다. 파일 이름의 girl/elder/caveman만으로 어린이·성인·성별이나 CHR 코드를 확정하지 않습니다.
- 두 Friendly_Caveman과 두 primitive_girl은 별도 원본입니다. 서로 대체하거나 중복으로 제거하지 않았습니다. 작은 파일도 원본 그대로 보존합니다.
- GLB에 참조된 외부 URI와 누락 파일 여부는 manifest에 기록합니다. 외형·원화 재현도·축/크기·바닥 접점·투명도·텍스처·면수·리깅·움직임은 실제 도구에서 후속 확인합니다.

## 개발 담당 사용 방법

Git LFS가 활성화된 저장소에서 이 폴더를 받고 `git lfs pull`로 원본 데이터를 내려받습니다. 파일이 `version https://git-lfs.github.com/spec/v1`로 시작하는 짧은 텍스트면 LFS 포인터이므로 실제 GLB가 아닙니다. 다운로드 후 manifest의 SHA-256과 비교합니다.

1. 원본을 보존한 채 검토용 복사본을 도구에서 열고 승인 원화의 인물과 대조합니다.
2. 용도·대응 인물을 정한 뒤 별도 경량본과 리깅/보행 동작을 제작합니다.
3. 실제 월드 배치·배회 경로·가림·충돌·Android 성능을 확인합니다. 모델 보관을 게임 적용 완료로 표시하지 않습니다.

최신 구현 상태: [개발 현황](../../../../docs/current-status.md). 이번 변경은 원본 보관과 개발 참고 문서이며 게임 코드·APK는 변경하지 않습니다.
