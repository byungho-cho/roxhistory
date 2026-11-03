# S40000 동물 리깅 원본 · 2026-11-03

사용자가 제공해 Git에 보관한 `../reference-v001`의 Brown Bear, Bunny Rabbit, Spotted Deer를 사용한다. 원본 GLB는 변경하지 않았다. 기존 경량화 모델 `game/assets/animals/{bear,deer,rabbit}.glb`의 형태·텍스처를 유지하고 15개 관절과 스킨 가중치를 추가했다.

- 편집 원본: 이 폴더의 종별 `.blend`, 관절 좌표 `.json`.
- 재현: Blender 4.5.3에서 `tools/rig_wildlife.py` 실행. 파일 첫머리의 명령 참조.
- 게임 파일: `game/assets/animals/*-rigged.glb` 및 Godot가 분리한 텍스처.
- 동작: `game/scripts/world_animal.gd`. 제한 반경에서 자동 이동·정지·고개 숙임, 네 다리 관절 회전, 토끼 도약. 수면·건물·플레이어 근접 회피, 앱 비활성 시 정지.
- 출처와 사용 조건은 제공 원본의 README를 계승한다. 사용자 제공 모델이며 별도의 상업 이용 라이선스 증빙은 추가 확인하지 않았다.

자동 생성 스킨과 절차적 동작이다. 수작업으로 제작한 전문 보행 클립과 동일한 품질로 간주하지 않는다. 방향별 관절 변형과 발 미끄러짐은 후속 미술 검토 대상이다.
