extends RefCounted

const MOTIONS := {
	"idle":"대기","walk":"걷기","run":"달리기","attack":"기본 공격",
	"hit":"피격","guard":"창 가드","counter":"반격","skill":"스킬",
	"thrust":"창 찌르기","short":"짧은 돌팔매","dodge":"회피","death":"사망","full":"전체 모션",
}
const CLIPS := {
	"uram":{"idle":"idle","walk":"walk","run":"run","attack":"club_attack","hit":"hit_reaction","skill":"parry","full":"full_motion"},
	"hangyeol":{"idle":"idle","walk":"walk","run":"run","attack":"basic_attack","hit":"hit_reaction","guard":"spear_guard","counter":"parry_counter","skill":"jump_spear_auto_r03","thrust":"stone_spear_thrust","full":"playlist"},
	"saebom":{"idle":"idle","walk":"walk","run":"run","attack":"basic_attack","hit":"hit_reaction","counter":"parry_counter","skill":"sling_heavy","short":"sling_cast","full":"playlist"},
}
const REPEATS := ["idle","walk","run"]

static func button_rect(index: int) -> Rect2:
	return Rect2(87+(index%7)*114,423+(index/7)*48,106,38)
