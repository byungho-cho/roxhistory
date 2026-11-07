class_name ResidentPanel
extends Control
## Small HUD entry point; uses the existing dialog skin and button language.
var app:Node
var counter_button:DemoButton
func _init(owner_app:Node)->void:app=owner_app
func _ready()->void:
	name="ResidentPanel";mouse_filter=Control.MOUSE_FILTER_IGNORE;z_index=6
	counter_button=app.button(self,"",show_summary);counter_button.name="ResidentCounter"
	counter_button.custom_minimum_size=Vector2.ZERO
	var bounds:Rect2=app.chrome.slot("residents")
	counter_button.position=bounds.position-Vector2(0,4);counter_button.size=Vector2(bounds.size.x,44)
	counter_button.hint_text="주민 수와 수용 인원 · 눌러서 작업 지정"
	for state in ["normal","hover","pressed","disabled","focus"]:counter_button.add_theme_stylebox_override(state,StyleBoxEmpty.new())
func job_name(job:String)->String:
	return {"wood":"나무꾼","stone":"돌 채집꾼","idle":"쉬는 중"}.get(job,"쉬는 중")
func resident_line(index:int)->String:
	var jobs:=ResidentJobs.new(app.model)
	var item:=jobs.entry("resident-%d"%index)
	var cargo:String=" · 본부로 운반 중" if not item.cargo.is_empty() else ""
	return "주민 %d · %s%s"%[index+1,job_name(str(item.job)),cargo]
func show_summary(page:int=0)->void:
	if app.screen!="play" or not app.application_active or app.world_map_open:return
	var count:int=app.model.resident_count()
	var body:="주민 %d명 / 수용 %d명\n주인공과 본부는 수용 인원에서 제외합니다.\n"%[count,app.model.resident_capacity()]
	var actions:Array=[]
	if count==0:
		body+="\n찾아온 1~3명의 방문객과 대화해 주세요. 모두 머물 빈자리가 있어야 합류하며, 움집을 짓거나 업그레이드하면 수용 인원이 늘어요."
	else:
		body+="\n작업을 맡기면 한 번 채집할 때마다 본부로 돌아와 재료를 넣습니다. 대상이 없으면 기다렸다가 다시 찾아요.\n"
		page=clampi(page,0,maxi(0,(count-1)/5))
		for i in range(page*5,mini(count,page*5+5)):
			body+="\n"+resident_line(i)
			var index:=i
			actions.append({"text":"주민 %d"%(i+1),"action":func():show_assignment(index)})
		if page>0:actions.append({"text":"이전 주민","action":func():show_summary(page-1)})
		if (page+1)*5<count:actions.append({"text":"다음 주민","action":func():show_summary(page+1)})
	if app.model.family_available():body+="\n\n방문객 %d명이 기다리는 중이에요."%app.model.family_visitor_count()
	if app.model.chief_level()<=0 and count>0:body+="\n본부가 없어 작업을 쉬고 있어요. 본부를 지으면 다시 시작해요."
	if app.model.built_count()>DemoConfig.MAX_RESIDENT_HOMES:body+="\n\n기존 움집 %d채는 보존 중입니다. 새 움집은 추가할 수 없어요."%app.model.built_count()
	actions.append({"text":"닫기","action":app.close_modal})
	app.show_modal("마을 주민",body,actions,false,true)
func show_assignment(index:int)->void:
	if index<0 or index>=app.model.resident_count():show_summary();return
	var body:=resident_line(index)+"\n\n나무꾼 또는 돌 채집꾼을 지정해 주세요.\n쉬기를 선택해도 이미 채집한 재료는 본부에 전달합니다."
	app.show_modal("주민 %d · 작업 지정"%(index+1),body,[
		{"text":"나무꾼","action":func():assign(index,"wood")},
		{"text":"돌 채집꾼","action":func():assign(index,"stone")},
		{"text":"쉬기","action":func():assign(index,"idle")},
		{"text":"뒤로","action":show_summary}],false,true)
func assign(index:int,job:String)->void:
	if not app.application_active:return
	if ResidentJobs.new(app.model).assign("resident-%d"%index,job):
		app.close_modal();app.toast("주민 %d · %s"%[index+1,job_name(job)])
