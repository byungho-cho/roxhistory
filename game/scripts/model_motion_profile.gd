extends RefCounted
# D0066 owns preview mappings, never gameplay rules or sound events.
const ANIMAL_NAMES={"forest":"forest-deer","stag":"mountain-stag","juvenile":"juvenile-boar","adult":"adult-boar"}
const ANIMAL_MODELS={
	"forest":"res://assets/animals/res050/forest-deer-latest.glb",
	"stag":"res://assets/animals/res050/mountain-stag-latest.glb",
	"juvenile":"res://assets/animals/res050/juvenile-boar-latest.glb",
	"adult":"res://assets/animals/res050/adult-boar-latest.glb",
}
const ALLY_CLIPS={
	"uram":{"skill":"req047_club_slam","chain":"parry","guard":"req045_shield_guard","counter":"req045_shield_counter","death":"req045_death"},
	"hangyeol":{"skill":"req047_ground_thrust","chain":"jump_spear_auto_r03","death":"req045_death"},
	"saebom":{"skill":"sling_heavy","chain":"req047_support_hangyeol","guard":"req045_evasive_guard","death":"req045_death"},
}
const ADDITIONS={
	"uram":["req045_shield_guard","req045_shield_counter","req045_death","req047_club_slam"],
	"hangyeol":["req045_death","req047_ground_thrust"],
	"saebom":["req045_evasive_guard","req045_death","req047_support_hangyeol"],
	"forest":["walk","run","hit_reaction","req046_idle","req046_basic_attack","req046_skill_anticipation","req046_skill_execute","req046_common_death"],
	"stag":["walk","run","hit_reaction","req046_idle","req046_basic_attack","req046_skill_anticipation","req046_skill_execute","req046_common_death"],
	"juvenile":["walk","run","hit_reaction","req046_idle","req046_run","req046_basic_attack","req046_hit","req046_skill_anticipation","req046_skill_execute","req046_common_death"],
	"adult":["walk","run","hit_reaction","req046_idle","req046_run","req046_basic_attack","req046_hit","req046_skill_anticipation","req046_skill_execute","req046_boss_death"],
}
const CONTACT={"forest":2.4903061224,"stag":2.4979591837,"juvenile":1.8563492063,"adult":2.225}
const DEATH_HOLD:=.6
const DEATH_FADE:=.6

static func install(player:AnimationPlayer,character:String)->void:
	# RES-050 contains complete approved clips. Never replace its reformed
	# channels with the older D0066 supplemental animations.
	var missing:Array=[]
	for clip in ADDITIONS[character]:
		if not player.has_animation(clip):missing.append(clip)
	if missing.is_empty():return
	var library:=player.get_animation_library("").duplicate()
	var animal:=ANIMAL_NAMES.has(character)
	var folder:="res://assets/"+("animals" if animal else "characters")+"/d0066/"
	var stem:String=ANIMAL_NAMES.get(character,character)
	for clip in missing:
		if library.has_animation(clip):library.remove_animation(clip)
		library.add_animation(clip,load(folder+stem+"-"+clip+".tres"))
	player.remove_animation_library("");player.add_animation_library("",library)

static func animal_clip(character:String,key:String)->String:
	match key:
		"idle":return "req046_idle"
		"walk":return "walk"
		"run":return "req046_run" if character in ["juvenile","adult"] else "run"
		"attack":return "req046_basic_attack"
		"hit":return "req046_hit" if character in ["juvenile","adult"] else "hit_reaction"
		"skill":return "skill_sequence"
		"death":return "req046_boss_death" if character=="adult" else "req046_common_death"
	return ""

static func animal_rate(character:String,clip:String)->float:
	if clip=="walk":return 1.75 if character in ["juvenile","adult"] else 1.5
	if clip in ["run","req046_run"]:return 1.25
	if clip=="req046_skill_execute":return 2.0
	return 1.0
