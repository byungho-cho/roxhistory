extends SceneTree
var checks:=0
var failures:Array[String]=[]
func _initialize()->void:call_deferred('run')
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures.append(label);push_error(label)
func run()->void:
 var model:=GameState.new(SaveStore.new('user://tests/resident_retouch_isolated_'+str(Time.get_ticks_usec())))
 model.start_new();var next:=model.state.duplicate(true);next.family_joined=true;model.commit(next)
 var world:=DemoWorld.new(model);root.add_child(world);await process_frame;await physics_frame
 world.set_physics_process(false)
 # Explicit actors avoid depending on onboarding/admission prerequisites.
 for variant in ['female','sturdy_male']:
  var fixture:=TrialResident.new();fixture.variant=variant;fixture.resident_id='resident-0' if variant=='female' else 'resident-1';fixture.set_physics_process(false);world.add_child(fixture);world.residents.append(fixture)
 var found:=false
 for resident in world.residents:
  resident.set_physics_process(false)
  if resident.variant=='sturdy_male':
   found=true
   if not resident.retouch_study:
    check(resident.visual.model_path.ends_with('residents/sturdy_male.glb'),'Default male source remains unchanged')
    check(not is_instance_valid(resident.carry_study),'Default mode has no prototype attachment')
    continue
   check(resident.visual.model_path.ends_with('resident-study/woodcutter-study.glb'),'Male trial loads copied resident model')
   check(is_instance_valid(resident.carry_study),'Carry attachment exists')
   var snapshot:=JSON.stringify(model.state)
   for kind in ['wood','stone','grain']:
    resident.carry_study.set_cargo({'kind':kind,'amount':10})
    check(resident.carry_study.displayed_kind==kind,'Correct cargo kind '+kind)
    for key in resident.carry_study.props:check(resident.carry_study.props[key].visible==(key==kind),'Only loaded prop visible '+kind+key)
    var pose:Transform3D=resident.carry_study.props[kind].transform
    check(pose.is_finite(),'Prop transform finite '+kind)
   resident.carry_study.set_cargo({})
   check(resident.carry_study.displayed_kind=='','Empty cargo clears state')
   for prop in resident.carry_study.props.values():check(not prop.visible,'Empty cargo hides all props')
   resident.carry_study.set_cargo({'kind':'wood','amount':0});check(resident.carry_study.displayed_kind=='','Zero quantity hidden')
   check(snapshot==JSON.stringify(model.state),'Presentation never mutates economy/job state')
  else:check(resident.visual.model_path.ends_with('residents/female.glb'),'Female source remains unchanged')
 check(found,'Male resident exercised')
 var result:={'checks':checks,'failures':failures,'scope':'Headless actual DemoWorld resident construction and presentation states, not rendered gameplay or device performance'}
 FileAccess.open('res://../art-source/resident-retouch-study/integration-validation'+('-enabled' if OS.get_cmdline_user_args().has('--resident-retouch-study') else '-default')+'.json',FileAccess.WRITE).store_string(JSON.stringify(result,'  '));print(JSON.stringify(result))
 world.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
