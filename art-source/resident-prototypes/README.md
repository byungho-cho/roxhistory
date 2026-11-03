# 주민 2명 시범 — 2026-11-03

기존 `art-source/meshy01/meshy01-hero.blend`의 15개 뼈대와 스킨 가중치를 재사용합니다. `tools/prepare_resident_prototypes.py`가 여성·건장한 남성의 실루엣, 땋은 머리, 가죽옷, 수염을 편집합니다. 유료 생성이나 외부 전송은 없습니다.

- 편집 원본: `female.blend`, `sturdy_male.blend` (원본 해상도 유지)
- 게임 파생본: `game/assets/characters/residents/` (각 16,000삼각형 목표, 1024px 텍스처, 약 1.3MB GLB)
- 공통 보행: `game/assets/characters/motion/brisk_walk_v001.tres`
- 보행 편집·재생성: `game/tests/bake_walk_clip.gd` (30트랙 × 65키, 1초 정규화 주기; 이동 거리에 맞춰 재생)
- 참고 원화: `design/assets/residents/v001/original/NPC-002_male-sturdy-builder_primitive_v002.png`, `NPC-003_female-young-forager_primitive_v002.png`

**시범 외형이며 원화 일치 완료본이 아닙니다.** 기존 주인공의 얼굴·신발·가죽옷 UV를 공유하므로 성인 체형·얼굴·맨발 표현은 별도 모델링이 필요합니다. 추가 머리카락과 옷의 변형도 최종 아트 검수가 필요합니다. 직업·대화·생산·보상 시스템은 추가하지 않습니다.

제공된 Meshy 원본의 이용 조건을 승계합니다. 계정별 이용권은 독립적으로 확인하지 않았습니다. 생성 출처와 원본 해시는 `provenance.json`에 기록합니다.
