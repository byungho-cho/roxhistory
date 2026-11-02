# FX-003 공통 건설 연출

승인 원화: construction-approved-storyboard.png. Figma 예시 579:83, 진행 UI 582:83, 망치 584:83.

construction-hammer-original.png는 Figma의 확정 에셋을 직접 내려받은 원본이다. 원형 배경 없이 72×76.8, x17, y-5.4를 사용한다. 진행바는 배경 72%, 녹색 채움 92%, 망치와 글자 100% 불투명도다. 망치는 약 0.6초 주기로 회전한다.

construction-scaffold-original.png는 built-in image_gen으로 승인 원화의 가운데 원형 목재 발판을 투명 게임 에셋으로 분리한 것이다. 게임 사본은 game/assets/effects/construction-scaffold.png에 있다. 생성 시 사용한 핵심 지시: "Extract/reconstruct ONLY the circular wooden construction scaffold from the MIDDLE panel; preserve warm golden brown timber and rope, overhead camera; empty transparent center; no completed hut, ground, dust, particles, text or UI." 출력에 남은 은은한 금빛은 연출의 일부로 보존했다.

모든 건축물은 같은 발판·먼지·금빛 입자·완료 링을 공유한다. 현재 데모 2초이며 경과/전체 시간으로 진행률을 계산하므로 이후 레벨별 시간 변경을 지원한다. 완료 모델은 GameState의 저장 성공 후 표시한다. 취소·실패 시 완료 연출을 재생하지 않는다.
